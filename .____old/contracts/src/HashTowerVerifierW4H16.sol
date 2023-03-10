//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );

/*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }
    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-add-failed");
    }
    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length,"pairing-lengths-failed");
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-opcode-failed");
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}
contract HashTowerVerifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }
    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = Pairing.G2Point(
            [4252822878758300859123897981450591353533073413197771768651442665752259397132,
             6375614351688725206403948262868962793625744043794305715222011528459656738731],
            [21847035105528745403288232691147584728191162732299865338377159692350059136679,
             10505242626370262277552901082094356697409835680220590971873171140371331206856]
        );
        vk.gamma2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.delta2 = Pairing.G2Point(
            [7547696603721272019833961280134273024096421899303183207081102556565821487812,
             1763346435417208746795385961847462487975213244463713296466207174465520706844],
            [16565420930060693698331818765820550553412310634816831443192947515222339201627,
             13276610515786267706049177828612445233248112279412001315622957227048350442756]
        );
        vk.IC = new Pairing.G1Point[](67);
        
        vk.IC[0] = Pairing.G1Point( 
            4210054087858465860587108017786963881993685142805862814901278147171746825091,
            14444901359046560593208475092584105630427016247887401181212632362357705419832
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            3466217327452830668578799665273397669048669980364232810245316647732251318543,
            9164679629082757191783117589757231770453561843017325551647157174184388749247
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            15222802264311865088623459837104779586694137129433260527624188908193402196635,
            6767572490274168022038325797957976274458405071402216193325255380693009274924
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            8354376752961731422679186846053276034022937230201276516022015973185034674319,
            1411732605366023850383960066584563500580356754884312990191404584217002156204
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            13467433332802042001747159561341689158454144052300531334765094794322423444197,
            17591202364333124501690650273083758099186203243845300482731521075423362285837
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            4625331376460786065759330065516521510711943405479582550428004107783099566118,
            15142911592978807679362578531188912553325941710267991177364622310370065216761
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            5790220949722652866667841723353651982663722133488456805373364988923483979894,
            2026807222203438183856187328817367967294448678657056081723244945499467691086
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            2008284698500358538527320864658858644595271377998945286667883171183352475648,
            14116360483004943287201250496709415927332797176946754295522117136982937577968
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            10247314742762336521070531582076625786709461631785718977460401078886557672356,
            14388688720065143179091472643834483806389350037515454885828793630596751368332
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            10987405270515244425106968142350596539430998002034260327954604640018944081402,
            16389733620470988535054441684950083518330177954924299161367880006817962601999
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            18341630442735654331978696888630643707314704929898130870973363229195160071401,
            14165742152508749215238637649062521207151073484824917566352495936381637243629
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            20028093160938383406996111036255656472455965103856889050836097617464777286431,
            11363114343595096263407668558074849912902765075352926182143977460882588327045
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            4049768690889051455734205663575342225748339351491785769807308922653135069683,
            3569333535969379339649217879783101271616594204096153358873751100249462930453
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            3990363859167402218975830147260042880395699828622778392591527617346951038693,
            842611551932345893109566744625061803453803409473336786862316242261606287462
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            18137057243387626523023049337444298284417663772000020010117568760897419573859,
            4376894563585261332362842449542425878416215905418569289330153636746891411931
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            15847170201423657265099737823174922973145852939798362206483752937200851883015,
            21216556482642101003607694098505928865006271337549958985286163437727601641801
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            6377560343321735929182338032410639165540866731103151845164636843522252441724,
            7430072904051577089953531933593849714999443856529751309967749593816137777525
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            21648806525204821609684965003536329124619715115900357356747716231360251112655,
            3529162895551607188776734841862744540321307373250857171428304161168799459798
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            9614074528890053756053692677529181699583178267170359295889870925930917320936,
            12953379480060897810862215918157758770478226623123346415952939773203193699066
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            722873256149385985325644889578249739169778555740867578526526464388598212695,
            18966843934659597408151171022390449051845239311194115082245761651350164914044
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            6334882653684103595042618771326345453038477466394149591853385962091338662144,
            3074821275424392973861903037983928422389473128579862735607281614800577666893
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            8704174035602930073124395619067796927623705969053333650423278454443579589732,
            15079457695340766457619869183708831508908020465336248436197438479447778325445
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            16483616280078905810714417644413369685984873627988108283508414512047360727407,
            6862783361902716976666700636974054023106271171134016719917251664150767783170
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            13340945470062122019253169624023735193764082521734807857464433345303059150871,
            16878614044609405286529177720103577095303256027091320458361788973304910661026
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            3270394236539444730656999386838736607014218633966335915296701591874176317568,
            10753133957051446128277861170518055722988721801742234159817257852014784068348
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            11234643469411433482846371683547854082280561574812718534498308040646660941292,
            10471835593180721653861902365450524807995882358715401489077672722653973452599
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            20522012393354385175487802867363775459366258741754451409319489617153699931931,
            7740390760400640567226929332502179596488296208858519114421766478497993657390
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            9996721546455775939324069412822988963072384469855904878961383041780637769367,
            7079558240546720945459054479332956499084191276127602124746106240907103305079
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            9388122974258726351589326475769825589350737572629051499684695110857753264621,
            7685054197638179453722353867562377490257954514074944437845018154448070060749
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            6647675793338540124167533678681624726382395385060444115643089324806847394634,
            7371102520769952505272296664679237154341161927065550962078642269335791753235
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            16191368835873335337028137801185800811252580469037663877591430737556469122724,
            15515674292378290968025559404189249106982654247739423837155299076568109877460
        );                                      
        
        vk.IC[31] = Pairing.G1Point( 
            18018347193953373956865120171978701257103516056631420476189242270153623236057,
            18454741630263757622194118923649809577010147835274658787927305043169403852676
        );                                      
        
        vk.IC[32] = Pairing.G1Point( 
            20387906083764475792431090481941005674024026965644783961352327058329087328435,
            2341113077423099589690238657247218966071225445462306196680228337124970097630
        );                                      
        
        vk.IC[33] = Pairing.G1Point( 
            3152923681136544584578002584152912517639004190395965735450889650997045542577,
            15262918672318843567279363452525730573442559618811612956537130107445374552599
        );                                      
        
        vk.IC[34] = Pairing.G1Point( 
            13001965417897154618938930366224464573498484389513341753586721800511513920801,
            6936250156306802644610645529392566527935411713091865907231158368525194266564
        );                                      
        
        vk.IC[35] = Pairing.G1Point( 
            15111051894703692308859557189661141558549759993018568859339959131255081799390,
            12473817664348819809061375466809557795010935608988291586562932407243125347594
        );                                      
        
        vk.IC[36] = Pairing.G1Point( 
            5766532109426082868130789363809057131032894780953588377725181318241056408890,
            12373228774205476625621915513337068734477095195699282420679570470897676000246
        );                                      
        
        vk.IC[37] = Pairing.G1Point( 
            10845458041892071371388040086486913365155432311582088306641276788220445837911,
            14983563229500054469866189554788881035688789191805070890568177195128554333683
        );                                      
        
        vk.IC[38] = Pairing.G1Point( 
            13342705828457087369208631600337096576084964566680222070240232859040974974528,
            11207224642157792839843327548219339331267974004716029924251713350669369042835
        );                                      
        
        vk.IC[39] = Pairing.G1Point( 
            21098604383789933351735763467699225095538535530423128960218602797719506572413,
            1350278995650316610076047914700369139971892563055074041709759253076618179028
        );                                      
        
        vk.IC[40] = Pairing.G1Point( 
            12347526289995798496661849043095452402542478004039144509903402455049462565841,
            20532203215817568759708799451061414114705112124675635017767230203842731680703
        );                                      
        
        vk.IC[41] = Pairing.G1Point( 
            2922787306286620291074452888592541311726677426447432494188790707511487686711,
            14695954381101710904489107168352256332775209248200467096560327113825417792397
        );                                      
        
        vk.IC[42] = Pairing.G1Point( 
            20575068794880462617148328494202953123669454913017565443835485751522809881842,
            2180817279332014606650339840657200299608823324966992343614067878547522669625
        );                                      
        
        vk.IC[43] = Pairing.G1Point( 
            18661872494825932694894188873015056327309796603010950813511597953378651074317,
            4950772572095173048658075349346498869403842123473587846332340290093889891504
        );                                      
        
        vk.IC[44] = Pairing.G1Point( 
            1441220789656358857373775701723051428455905518947417291773655033634264473689,
            18093474412101773356072110427571086458600912634240203924236627820685025487411
        );                                      
        
        vk.IC[45] = Pairing.G1Point( 
            17239391918885734922409972731711103589426794852983909248527135321484445747192,
            13389553145074325896991923684369939301620116056231656347027184161650198240110
        );                                      
        
        vk.IC[46] = Pairing.G1Point( 
            18582318921873268171276672790950318119351244198484232813762774784326329978401,
            2887840696243062077158997066305158347021682718568990456153884840336583876727
        );                                      
        
        vk.IC[47] = Pairing.G1Point( 
            18234082273173381539373261092493519849488240182727362773118549595829581821986,
            4845042474120517414090312275802373673220162613564021958417343069326702159189
        );                                      
        
        vk.IC[48] = Pairing.G1Point( 
            17828944665946924614289436438335300457676460861731512834967894487204714900427,
            13156942303235729584474931911755363174365208389879503226502447866981985266611
        );                                      
        
        vk.IC[49] = Pairing.G1Point( 
            20710980229177543528246373825677622503669970378434597806756165581767192493755,
            14155051612849226546062066439199586561045041691030563625672981120537957899078
        );                                      
        
        vk.IC[50] = Pairing.G1Point( 
            4634222319273187232314766560708910276217694526003984128762954461468436925396,
            16001422657942797977566850815636121973915067741474198449642352398785325043026
        );                                      
        
        vk.IC[51] = Pairing.G1Point( 
            7362378952114526827086560587629734310143104829982857161822250430713221059329,
            12721338571113136499189541442029070589971306375327498238858620638034117034987
        );                                      
        
        vk.IC[52] = Pairing.G1Point( 
            20127215503044567613712421955824853760893256743161307060070643312438318418732,
            14254124637399846669759960469277702774587539412064987535708852597793673086609
        );                                      
        
        vk.IC[53] = Pairing.G1Point( 
            17254793527013142063563033174442954967377650707920992356307088325080463666309,
            2025011282297119501897837066897769116365669819837348440906264073278024023242
        );                                      
        
        vk.IC[54] = Pairing.G1Point( 
            6894877784860229763451319097358256730616611608782586028029977945476496290787,
            9432046858471507242829371694653296899871589978594006572735988395432976909210
        );                                      
        
        vk.IC[55] = Pairing.G1Point( 
            10736143538197432624251597151791854310207107822920520004203294987921614997377,
            8301453636509187435625748294503506845621742364610772955094675702786161364970
        );                                      
        
        vk.IC[56] = Pairing.G1Point( 
            1987686396369949978503450877161535673679024727258153177162559663076941896894,
            9081795673630143265405199937798947242960333343501312544107662330053734795867
        );                                      
        
        vk.IC[57] = Pairing.G1Point( 
            19752315607595007834377505957874048053781384970393928609655476758986355950452,
            2090623601177807320046254139171229478049788929786318562065571489359606431977
        );                                      
        
        vk.IC[58] = Pairing.G1Point( 
            18827007084377874064389209603670072177325176148422645834625593821621941547837,
            8231722169794988960083546480091506470167845223991317271635914782396935528779
        );                                      
        
        vk.IC[59] = Pairing.G1Point( 
            14195831162648171832530349704175801769038181586196536593550335749205582806669,
            18832443586944812184608603750582104734644358115123610873047229796582854425819
        );                                      
        
        vk.IC[60] = Pairing.G1Point( 
            18895866668212550076479221843412496883688740807239540058093766918645366638845,
            13760760141028553169759573007320668037990385014365882319826299766421355957006
        );                                      
        
        vk.IC[61] = Pairing.G1Point( 
            9059995058780600421787261975460805151454095602998820712110312378388687605754,
            494983811581178673666542709326264002241806024272749127094001871521655492693
        );                                      
        
        vk.IC[62] = Pairing.G1Point( 
            12428999270838149863840594452129585801973786000524706649709874101057842422287,
            3478617564867229383900448609275881497170376623081175116952226166342375229945
        );                                      
        
        vk.IC[63] = Pairing.G1Point( 
            3261569775639976183894643905695917039811045232157983288292078799458052454164,
            15481493252215338613116054415209470472387081479014629209954264313600855515306
        );                                      
        
        vk.IC[64] = Pairing.G1Point( 
            3005496621566801058465274912871966890534896896542887760565471339381233105102,
            9353535187351438914011691878076861607692450258794680757536374189032695301524
        );                                      
        
        vk.IC[65] = Pairing.G1Point( 
            11252946764703460278261910365647128924096235670279188962749085268949579562579,
            1148102140742249772069297620323413466289813221360963460293360880119523600116
        );                                      
        
        vk.IC[66] = Pairing.G1Point( 
            13173148004899088164093184059081143995899158679092513328285208785597964096351,
            13116426857979941831377137983673425709381890852644719507433008245001543336504
        );                                      
        
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        if (!Pairing.pairingProd4(
            Pairing.negate(proof.A), proof.B,
            vk.alfa1, vk.beta2,
            vk_x, vk.gamma2,
            proof.C, vk.delta2
        )) return 1;
        return 0;
    }
    /// @return r  bool true if proof is valid
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[66] memory input
        ) public view returns (bool r) {
        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
