"use strict";
import { poseidon } from "circomlibjs"; // for off-line computing

const prof = {
    read: 0, write: 0, hash: 0,
    r: function() { this.read++ },
    w: function() { this.write++ },
    h: function() { this.hash++ },
    toString: function() { return `r: ${this.read} w: ${this.write} h: ${this.hash}` }
};

const W = 4;
const H = 20; // 4^0 + 4^1 + ... + 4^19 = 366503875925
const DEBUG_RANGE = true;

// simulating a Solidity storage struct
class HashTowerData {
    constructor() {
        this.length = 0;
        this.buf = Array.from({length: H}, () => Array(W).fill('_')); // fill _ for visual affects only
    }
    getLength()        { prof.r(); return this.length; }
    setLength(l)       { prof.w(); this.length = l; }
    getBuf(lv, idx)    { prof.r(); return this.buf[lv][idx]; }
    setBuf(lv, idx, v) { prof.w(); this.buf[lv][idx] = v; }
}

// simulating a Solidity library
class HashTower {
    hash(arr) {
        prof.h();
        if (!DEBUG_RANGE) {
            return poseidon(arr);
        } else {
            return [arr[0][0], arr[W - 1][1]]; // for visualizing
        }
    }
    add(self, item) {
        const len = self.getLength();
        const lvLengths = this.getLevelLengths(len);

        var toAdd;
        if (!DEBUG_RANGE) {
            toAdd = BigInt(item);
        } else {
            toAdd = [item, item]; // for visualizing
        }

        for (let lv = 0; lv < H; lv++) {
            const origLvLen = lvLengths[lv];
            if (origLvLen < W) {
                self.setBuf(lv, origLvLen, toAdd);
                break;
            } else {
                const bufLv = Array.from({length: W}, (v, i) => self.getBuf(lv, i));
                const hash = this.hash(bufLv);
                self.setBuf(lv, 0, toAdd);
                toAdd = hash; // to be added in the upper level
            }
        }
        self.setLength(len + 1);
    }
    getLevelLengths(len) {
        var lengths = [];
        var zeroIfLessThan = 0; // W^0 + W^1 + W^2 ... (1 + 4 + 16 + ...)
        var pow = 1; // pow = W^lv
        for (let lv = 0; lv < H; lv++) {
            zeroIfLessThan += pow;
            const lvLen = (len < zeroIfLessThan) ? 0 : Math.floor((len - zeroIfLessThan) / pow) % W + 1;
            lengths.push(lvLen); // zero-terminated
            if (lvLen == 0) break;
            pow *= W; // shift
        }
        return lengths;
    }
    // direct access without triggering profiling
    show(len, buf) {
        console.clear();
        var lengths = this.getLevelLengths(len);
        for (let lv = H - 1; lv >= 0; lv--) {
            var msg = "lv " + lv + "\t";
            for (let i = 0; i < W; i++) {
                const s = "" + buf[lv][i];
                msg += s.length > 20
                    ? s.substring(0, 17) + "..."
                    : s.padStart(20, " ");
                msg += (i == lengths[lv] - 1) ? " |  " + "\x1b[90m" : "    ";
            }
            msg += "\x1b[0m";
            console.log(msg);
        }
        console.log("\n");
        console.log("length: " + len);
        console.log("profiling:", prof.toString());
        console.log("level lengths: " + lengths + ",...");
        console.log("getPositions(0): ", ht.getPositions(0, len));
        var start = new Date().getTime(); while (new Date().getTime() < start + 1000);
    }
    // only for proving
    getPositions(idx, len) {
        if (idx < 0 || idx >= len) return undefined;
        const lvLengths = this.getLevelLengths(len);
        var start = len;
        var pow = 1;
        for (let lv = 0; lv < H; lv++) {
            for (let lvIdx = lvLengths[lv] - 1; lvIdx >= 0; lvIdx--) {
                start -= pow;
                if (start <= idx) {
                    return [lv, lvIdx, start, pow];
                }
            }
            pow *= W;
        }
        return undefined;
    }
}


const htd = new HashTowerData();
const ht = new HashTower();
ht.show(htd.length, htd.buf);
for (let i = 0; i < 10000000; i++) {
    ht.add(htd, i);
    //ht.show(htd.length, htd.buf);
}
ht.show(htd.length, htd.buf);
