const F = [];

function fade(t) {
    return t * t * t * (t * (t * 6 - 15) + 10);
}

for (let i = 0; i < 256; i++) {
    F[i] = Math.floor(((1<<12) * fade(i/256)));
}

printBranch(0, 255);

function printBranch(low, high) {
    if (high - low < 3) {
        const a = F[low] << 12 | F[Math.min(255, low+1)];
        const b = F[high] << 12 | F[Math.min(255, high+1)];
        console.log("if (i == %d) { return %d; } else { return %d; }", low, a, b);
        return;
    }

    const middle = Math.floor((high+low)/2);
    console.log("if (i <= %d) {", middle);
    printBranch(low, middle);
    console.log("} else {");
    printBranch(middle+1, high);
    console.log("}");
}