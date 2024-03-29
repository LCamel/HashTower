"use strict";
//import { PolysumTower, buildL, buildMerkleProofAndLocateRoot, padInput } from "../../src/Dev.mjs";
import { DigestDigestTower } from "../../src/Dev.mjs";
import { buildL, buildMerkleProofAndLocateRoot, padInput } from "../../src/Proof.mjs";
import { poseidon } from "circomlibjs";
import { groth16 } from "snarkjs";
import * as fs from "fs";


//function P1(v) {
//    return poseidon([v]);
//}

//const FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617n;
//const R = 2n;
//const R = 18394430908091344617384880311697507424035533102877559791950913628996628114390n;
const H = 20;
const W = 4;
//let t = PolysumTower(W, P1, R, FIELD_SIZE);
//const eventFetcher = (lv, start, len) => t.E[lv].slice(start, start + len);
let incDigest = (acc, v, i) => (i == 0) ? v : poseidon([acc, v]);
let t = DigestDigestTower(W, incDigest, incDigest);
let eventFetcher = (lv, start, len) => t.E[lv].slice(start, start + len);






// groth16 acceps both file name and file content
//const c = "HashTowerPolysumH4W4R2";
const c = "HashTowerWithHashList";
const WASM = fs.readFileSync(`./out/${c}_js/${c}.wasm`);
const ZKEY = fs.readFileSync(`./out/${c}_js/${c}_0001.zkey`);
const VKEY = JSON.parse(fs.readFileSync(`./out/${c}_js/verification_key.json`));


for (let i = 0; i < 85; i++) {
    t.add(i);
    let count = i + 1;

    for (let j = 0; j <= i; j++) {
        //let input = padInput(t.W, H, t.dd,
        //    buildL(count, t.W, eventFetcher),
        //    ...buildMerkleProofAndLocateRoot(count, t.W, eventFetcher, j));
        let L = buildL(count, W, eventFetcher);
        let input = padInput(W, H, count, t.DD[0], L,
            ...buildMerkleProofAndLocateRoot(count, W, eventFetcher, j));

        console.log(input);

        let t0 = Number(Date.now());
        const { proof, publicSignals } = await groth16.fullProve(input, WASM, ZKEY);
        console.log(proof);
        console.log(publicSignals);
        let t1 = Number(Date.now());
        console.log("fullProve took: ", (t1 - t0));

        if (!await groth16.verify(VKEY, publicSignals, proof)){
            throw "verification failed!"; // $? will become 1
        }
    }
}

// It seems that snarkjs can't gracefully terminate the workers.
process.exit(0);
