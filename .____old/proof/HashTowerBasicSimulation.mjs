"use strict";
import { poseidon } from "circomlibjs";

// COMMON

const W = 4; // 4 * (4^0 + 4^1 + ... 4^11) = 22369620,  4 * (4^0 + 4^1 + ... 4^15) = 5726623060
const H = 4;

const DEBUG_RANGE = process.env.DEBUG_RANGE; // toggle it to observe the algorithm
const EQ = !DEBUG_RANGE ? ((a, b) => a == b) : ((ra, rb) => ra[0] == rb[0] && ra[1] == rb[1]);
const ZERO = !DEBUG_RANGE ? BigInt(0) : [0, 0];
const HASH = !DEBUG_RANGE ? poseidon : (ranges) => [ranges[0][0], Math.max(...ranges.map((r) => r[1]))];

// Level lengths in the tower. This is the "shape" of the tower.
// lv 2: (0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0) 1  1  1  1  1  1 ...
// lv 1: (0  0  0  0  0) 1  1  1  1  2  2  2  2  3  3  3  3  4  4  4  4  1  1  1  1  2  2 ...
// lv 0: (0) 1  2  3  4  1  2  3  4  1  2  3  4  1  2  3  4  1  2  3  4  1  2  3  4  1  2 ...
// len :  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 ...
//
// Level full lengths (including parts not in the tower). These are only used by events.
// lv 2: (0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0) 1  1  1  1  1  1 ...
// lv 1: (0  0  0  0  0) 1  1  1  1  2  2  2  2  3  3  3  3  4  4  4  4  5  5  5  5  6  6 ...
// lv 0: (0) 1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 ...
// len :  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 ...
function getLevelFullLengths(len) {
    var lengths = Array(H).fill(0);
    var zeroIfLessThan = 0;
    var pow = 1; // pow = W^lv
    for (let lv = 0; lv < H; lv++) {
        zeroIfLessThan += pow; // W^0 + W^1 + W^2 ... (1 + 4 + 16 + ...)
        const lvLen = (len < zeroIfLessThan) ? 0 : Math.floor((len - zeroIfLessThan) / pow) + 1;
        if (lvLen == 0) break;
        lengths[lv] = lvLen;
        pow *= W; // use shift if W is power of 2
    }
    return lengths;
}
function toInTowerLength(fullLen) {
    return fullLen == 0 ? 0 : (fullLen - 1) % W + 1;
}
function getLevelInTowerLengths(len) {
    return getLevelFullLengths(len).map(toInTowerLength);
}

// CIRCUIT

// claiming that childrens[0][indexes[0]] belongs to the original item list
function verify(lv0Len, levels, childrens, indexes, matchLevel) {
    // attackers can't aim at a tailing 0 hash above lv0, so we only check the lv0 case
    const lv0Safe = (matchLevel != 0) || (indexes[0] < lv0Len);

    const chHashes = childrens.map(HASH);

    const isMerkleProof = childrens.every((children, lv) =>
        lv == 0 ? true : EQ(children[indexes[lv]], chHashes[lv - 1]));

    const rootMatches = EQ(childrens[matchLevel][indexes[matchLevel]],
                              levels[matchLevel][indexes[matchLevel]]);

    console.log("verify: ", { lv0Safe, isMerkleProof, rootMatches });
    console.log("matching level children: ", childrens[matchLevel]);
    return lv0Safe && isMerkleProof && rootMatches;
}

// CONTRACT

const events = Array.from({length: H}, () => []);
function emit(lv, lvIdx, val) {
    events[lv][lvIdx] = val;
}
function getEvents(lv, start, end) {
    return events[lv].slice(start, end); // end exclusive
}


class Profiler {
    constructor() { this.read = this.write = this.hash = 0 }
    r() { this.read++ }
    w() { this.write++ }
    h() { this.hash++ }
    toString() { return `read: ${this.read} write: ${this.write} hash: ${this.hash}` }
};
const PROF_ADD = new Profiler();
const PROF_PROVE = new Profiler();
var profiler;

class HashTowerData { // struct HashTowerData
    constructor() {
        this.length = 0;
        this.levels = Array.from({length: H}, () => Array(W));
    }
    getLength()         { profiler.r(); return this.length; }
    setLength(l)        { profiler.w(); this.length = l; }
    getLvAt(lv, idx)    { profiler.r(); return this.levels[lv][idx]; }
    setLvAt(lv, idx, v) { profiler.w(); this.levels[lv][idx] = v; }
}

class HashTower { // library HashTower
    add(self, item) {
        profiler = PROF_ADD;
        const len = self.getLength(); // the length before adding the item
        const lvFullLengths = getLevelFullLengths(len); // TODO: inline this function in the loop (solidity)
        var toAdd = item;
        for (let lv = 0; lv < H; lv++) {
            const lvLen = toInTowerLength(lvFullLengths[lv]);
            if (lvLen < W) { // not full
                self.setLvAt(lv, lvLen, toAdd);
                emit(lv, lvFullLengths[lv], toAdd);
                break;
            } else { // full
                const lvHash = HASH(Array.from({length: W}, (_, i) => self.getLvAt(lv, i))); profiler.h();
                self.setLvAt(lv, 0, toAdd); // add it in the now-considered-being-emptied level
                emit(lv, lvFullLengths[lv], toAdd);
                toAdd = lvHash; // to be added in the upper level
            }
        }
        self.setLength(len + 1);
    }
    prove(self, childrens, indexes, matchLevel) {
        profiler = PROF_PROVE;
        const levels =  Array.from({length: H}, () => Array(W));
        const lvLengths = getLevelInTowerLengths(self.getLength()); // only load slots we need
        for (let lv = 0; lv < H; lv++) {
            for (let i = 0; i < lvLengths[lv]; i++) {
                levels[lv][i] = self.getLvAt(lv, i); // pad ZERO if lvHash is needed
            }
        }
        return verify(lvLengths[0], levels, childrens, indexes, matchLevel);
    }
}

// PROVER

function generateMerkleProofFromEvents(itemIdx) {
    const childrens = [];
    const indexes = [];
    var lvFullIdx = itemIdx;
    for (let lv = 0; lv < H; lv++) {
        const chIdx = lvFullIdx % W;
        const chStart = lvFullIdx - chIdx;
        const events = getEvents(lv, chStart, chStart + W);
        if (events[chIdx] === undefined) break;
        childrens.push(Array.from({length: W}, (_, i) => i < events.length ? events[i] : ZERO));
        indexes.push(chIdx);
        if (events[W - 1] === undefined) break;
        lvFullIdx = Math.floor(lvFullIdx / W);
    }
    if (childrens.length == 0) return undefined;
    const matchLevel = childrens.length - 1;

    // make it a Merkle proof all the way to the top
    for (let lv = childrens.length; lv < H; lv++) {
        childrens.push(Array.from({length: W}, (_, i) => i == 0 ? HASH(childrens[lv - 1]) : ZERO));
        indexes.push(0);
    }
    return [childrens, indexes, matchLevel];
}

// DEMO

function show(len, levels) { // direct access without triggering profiling
    var lvLengths = getLevelInTowerLengths(len);
    for (let lv = H - 1; lv >= 0; lv--) {
        var msg = "lv " + lv + "\t";
        for (let i = 0; i < W; i++) {
            const s = String(levels[lv][i] ?? '_');
            msg += s.length > 20 ? s.substring(0, 17) + "..." : s.padStart(20, " ");
            msg += (i == lvLengths[lv] - 1) ? " ↵  " + "\x1b[90m" : "    "; // ↵
        }
        msg += "\x1b[0m";
        console.log(msg);
    }
    console.log("\n");
    console.log("length: " + len);
    console.log("profiling: add(): " + PROF_ADD);
    console.log("         prove(): " + PROF_PROVE);
    console.log("level in tower lengths: " + lvLengths);
    console.log("level full lengths    : " + getLevelFullLengths(len));
}

const htd = new HashTowerData();
const ht = new HashTower();
console.clear();
show(htd.length, htd.levels);
//for (let i = 0; i < 1000000; i++) {
for (let i = 0; i < 25; i++) {
    if (i >= 24) await new Promise(r => setTimeout(r, 1000)); // may skip sleeping
    console.clear();

    const item = !DEBUG_RANGE ? BigInt(i) : [i, i];
    ht.add(htd, item);
    show(htd.length, htd.levels);
    console.log("proof for idx 10: ");
    const proof = generateMerkleProofFromEvents(10);
    if (proof) {
        console.log("prove: ", ht.prove(htd, ...proof));
    }
}

// generate a input.json for the circom verifier
const proof = generateMerkleProofFromEvents(10);
const lvInTowerLengths = getLevelInTowerLengths(htd.length);
const levels = Array.from({length: H}, () => Array(W));
for (let lv = 0; lv < H; lv++) {
    for (let i = 0; i < W; i++) {
        levels[lv][i] = (i < lvInTowerLengths[lv]) ? htd.levels[lv][i] : 0;
    }
}

const inputJson = {
    lv0Len: lvInTowerLengths[0],
    levels: levels,
    childrens: proof[0],
    indexes: proof[1],
    matchLevel: proof[2]
};


BigInt.prototype.toJSON = function() { return this.toString() }

console.log(JSON.stringify(inputJson));
