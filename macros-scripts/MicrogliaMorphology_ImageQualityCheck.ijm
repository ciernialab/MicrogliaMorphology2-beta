// =============================================================================
// MicrogliaMorphology_ImageQualityCheck.ijm
//
// Measures the cell-to-background contrast and the signal-to-noise ratio (SNR)
// of a test image from regions you select, and tells you which background /
// SNR class of the benchmark the image falls into, with suggested settings.
//
// HOW TO USE
//   1. Open one representative image (single channel; for a stack or
//      hyperstack the CURRENT plane/channel is used) and run this macro.
//   2. Draw the cell examples: trace WHOLE cells (soma plus processes) with
//      the freehand or polygon tool, press OK in the prompt, repeat.
//   3. Draw the background examples: areas with NO cells, at least about
//      40 x 40 pixels, that are typical of the background (include haze and
//      fibres, not only the darkest area). Rectangles are fine.
//   4. Read the Log window and the "Results" table (one row per run, so you can
//      run several images and save the table).
//
// WHAT IS MEASURED (same definitions as the benchmark images)
//   Contrast ratio = median pixel value inside the cell regions
//                    / median pixel value inside the background regions
//   SNR            = (median cell - median background) / noise SD
//   Noise SD       = robust (median absolute deviation) estimate from the
//                    diagonal high-frequency detail of the image inside the
//                    background regions, (I(x,y) - I(x+1,y) - I(x,y+1) + I(x+1,y+1)) / 2.
//                    This is not affected by smooth background or by sparse
//                    structure, and equals the noise SD for pixel-independent noise.
//
// CHECKED ON THE 10 BENCHMARK IMAGES (done outside ImageJ with the same formulas)
//   Contrast ratio reproduced exactly (2.48 ... 1.66).
//   Noise SD from 100 x 100 px background regions was within about 10% of the
//   true added noise, giving SNR 15-22 for the high-SNR images (true 17-20) and
//   4.3-4.5 for the low-SNR images (true 4.3). Expect roughly +-20% on real data.
//
//   Benchmark reference (contrast ratio / SNR):
//     bg1 2.48 (low background)      high SNR 19.9   low SNR 4.3
//     bg2 2.11, bg3 1.89 (medium)    high SNR 18-19  low SNR 4.3
//     bg4 1.75, bg5 1.66 (high)      high SNR 17     low SNR 4.3
//
// LIMITS
//   * Contrast depends on how the cell regions are drawn. Tracing only the soma
//     overestimates it compared with the benchmark, which used whole cells.
//   * The noise estimate assumes pixel-independent noise. Images that were
//     smoothed, resampled, deconvolved or JPEG-compressed will give too low a
//     noise value (too high an SNR).
//   * The recommendations come from synthetic images with one cell layout and
//     should be checked on real images.
// =============================================================================

requires("1.52a");

// variables used inside functions must be declared with var at the top level
var origID = 0;
var origTitle = "";

// ----------------------------- settings --------------------------------------
var nCellsDefault = 5;
var nBgDefault    = 5;
var minBgSide     = 40;      // warn if a background region is smaller than this (pixels)

// classification (from the benchmark: contrast 2.48 / 2.11 / 1.89 / 1.75 / 1.66)
var contrastLowBg   = 2.3;   // >= this  : low background
var contrastHighBg  = 1.8;   // <  this  : high background (between: medium)
var snrHigh         = 12;    // >= this  : high SNR (benchmark 17-20)
var snrLow          = 8;     // <  this  : low SNR (benchmark 4.3); in between: intermediate

// benchmark acquisition values used to convert settings to your pixel size
var benchPixel   = 0.3447;   // um per pixel
var benchRadiusUm = 34.47;   // 100 px local-threshold radius at 0.3447 um/px

// ----------------------------- start-up checks -------------------------------
if (nImages == 0)
    exit("Open a representative image first, then run the macro again.");

origID    = getImageID();
origTitle = getTitle();
if (bitDepth() == 24)
    exit("This is an RGB image. Convert it to a single-channel 8-bit, 16-bit or 32-bit image first.");

Dialog.create("Image quality check");
Dialog.addMessage("Image: " + origTitle + "\nThe current plane / channel is measured.");
Dialog.addNumber("Number of cell examples:", nCellsDefault, 0, 3, "");
Dialog.addNumber("Number of background examples:", nBgDefault, 0, 3, "");
Dialog.addMessage("Trace WHOLE cells (soma plus processes). Background regions must contain no cells.");
Dialog.show();
nCells = round(Dialog.getNumber());
nBg    = round(Dialog.getNumber());
if (nCells < 1 || nBg < 1) exit("Select at least one cell and one background region.");

run("Set Measurements...", "area mean standard modal min median redirect=None decimal=3");
roiManager("reset");
selectImage(origID);
run("Select None");

// ----------------------------- collect regions -------------------------------
cellIdx = collectRegions("cell", nCells, "freehand",
    "Trace one WHOLE cell (soma and processes) with the freehand or polygon tool, then click OK.");
bgIdx   = collectRegions("bg", nBg, "rectangle",
    "Draw one BACKGROUND region with no cells (at least " + minBgSide + " x " + minBgSide
    + " px; include typical haze and fibres), then click OK.");
if (cellIdx.length == 0 || bgIdx.length == 0) exit("Need at least one cell and one background region.");

// ----------------------------- working copies --------------------------------
rawID = getPlane("QC_raw");               // plane at original bit depth
selectImage(origID);
noiseID = getPlane("QC_noise");           // 32-bit diagonal detail image
run("32-bit");
run("Convolve...", "text1=[1 -1 0\n-1 1 0\n0 0 0\n]");
run("Divide...", "value=2");

// ----------------------------- measurements ----------------------------------
cellStats = pooledStats(rawID, cellIdx);  // [median, mean, SD, area]
bgStats   = pooledStats(rawID, bgIdx);
medCell = cellStats[0];
medBg   = bgStats[0];
if (medBg <= 0) exit("Background median is zero or negative; contrast ratio cannot be computed.");
contrast = medCell / medBg;

dStats = pooledStats(noiseID, bgIdx);
selectImage(noiseID);
run("Duplicate...", "title=QC_dev");
devID = getImageID();
run("Subtract...", "value=" + d2s(dStats[0], 6));
run("Abs");
madStats = pooledStats(devID, bgIdx);
noiseSD = 1.4826 * madStats[0];
if (noiseSD <= 0) exit("Noise estimate is zero. The background regions may be saturated or constant.");
snr = (medCell - medBg) / noiseSD;

// consistency of the noise estimate across background regions
nMin = 1e30; nMax = 0;
for (i = 0; i < bgIdx.length; i++) {
    v = 1.4826 * roiMedian(devID, bgIdx[i]);
    if (v < nMin) nMin = v;
    if (v > nMax) nMax = v;
}
// spread of the cell regions
cMin = 1e30; cMax = -1e30;
for (i = 0; i < cellIdx.length; i++) {
    v = roiMedian(rawID, cellIdx[i]);
    if (v < cMin) cMin = v;
    if (v > cMax) cMax = v;
}

// small background regions
smallBg = 0;
for (i = 0; i < bgIdx.length; i++) {
    selectImage(rawID);
    roiManager("select", bgIdx[i]);
    getSelectionBounds(bx, by, bw, bh);
    if (bw < minBgSide || bh < minBgSide) smallBg++;
}
run("Select None");

// saturation and pixel size
selectImage(rawID);
satFrac = saturationFraction();
getPixelSize(unit, pw, ph);
isUm = (unit == fromCharCode(181) + "m" || unit == fromCharCode(956) + "m" || unit == "um" || unit == "micron" || unit == "microns");
calibrated = isUm;

// ----------------------------- classify --------------------------------------
if (contrast >= contrastLowBg)       bgClass = "LOW background";
else if (contrast >= contrastHighBg) bgClass = "MEDIUM background";
else                                 bgClass = "HIGH background";

if (snr >= snrHigh)     snrClass = "HIGH SNR";
else if (snr < snrLow)  snrClass = "LOW SNR";
else                    snrClass = "INTERMEDIATE SNR";

// ----------------------------- report ----------------------------------------
print("\\Clear");
print("==== Image quality check: " + origTitle + " ====");
print("Cell regions: " + cellIdx.length + "   Background regions: " + bgIdx.length);
print("Median cell value:        " + d2s(medCell, 1) + "   (per-region medians " + d2s(cMin, 1) + " to " + d2s(cMax, 1) + ")");
print("Median background value:  " + d2s(medBg, 1));
print("Noise SD (robust):        " + d2s(noiseSD, 2) + "   (per-region " + d2s(nMin, 2) + " to " + d2s(nMax, 2) + ")");
print("");
print("Contrast ratio (cell / background): " + d2s(contrast, 2));
print("SNR ((cell - background) / noise):  " + d2s(snr, 1));
print("");
print("Classification:  " + bgClass + ",  " + snrClass);
print("Benchmark: contrast 2.48 (bg1), 2.11 (bg2), 1.89 (bg3), 1.75 (bg4), 1.66 (bg5); SNR 17-20 (high) and 4.3 (low)");
print("");

warnings = newArray(0);
if (contrast > 2.7 || contrast < 1.5)
    warnings = Array.concat(warnings, "Contrast " + d2s(contrast, 2) + " is outside the benchmarked range (1.66 to 2.48); the advice is an extrapolation.");
if (snr > 25 || snr < 3)
    warnings = Array.concat(warnings, "SNR " + d2s(snr, 1) + " is outside the benchmarked range (4.3 to 20); the advice is an extrapolation.");
if (nMin > 0 && nMax / nMin > 1.5)
    warnings = Array.concat(warnings, "The noise estimate differs by more than 1.5x between background regions; some may contain structure or cells. Check the regions.");
if (smallBg > 0)
    warnings = Array.concat(warnings, smallBg + " background region(s) are smaller than " + minBgSide + " x " + minBgSide + " px; the noise estimate is less reliable.");
if (cellIdx.length < 3)
    warnings = Array.concat(warnings, "Fewer than 3 cell regions; the contrast estimate is unreliable.");
if (satFrac > 0.001)
    warnings = Array.concat(warnings, "About " + d2s(100 * satFrac, 2) + "% of pixels are at the image maximum (saturation). The benchmark had < 0.0001%.");
if (!calibrated)
    warnings = Array.concat(warnings, "The image is not calibrated in microns (unit: " + unit + "). Set the scale with Analyze > Set Scale. The radius below is the benchmark value in pixels (benchmark pixel size " + benchPixel + " um/px).");
if (warnings.length > 0) {
    print("WARNINGS");
    for (i = 0; i < warnings.length; i++) print("  - " + warnings[i]);
    print("");
}

// suggested settings
radiusPx = "100 px (benchmark value; set the radius to about " + d2s(benchRadiusUm, 1) + " um for your pixel size)";
if (calibrated) {
    radiusVal = Math.round(benchRadiusUm / parseFloat("" + pw));
    radiusPx = "" + d2s(radiusVal, 0) + " px (= " + d2s(benchRadiusUm, 1) + " um at your pixel size of " + d2s(parseFloat("" + pw), 4) + " " + unit + ")";
}
print("SUGGESTED SETTINGS (from the benchmark; check on your own images)");
print("  Always: use soma-seeded splitting (Gaussian sigma 3 um, prominence 8), include the unsharp mask,");
print("          do not use Otsu. Contrast stretch and despeckle gave no consistent benefit.");
if (bgClass == "LOW background") {
    if (snrClass == "HIGH SNR") {
        print("  Method:  Tubeness, cutoff 20 (Tube3 or TubeOrig), with splitting.");
        print("  Filter:  lower area filter 50-100 um^2 (100 removes about half of the non-cell particles at little cost).");
        print("  Alternative: Niblack or Mean local threshold (radius " + radiusPx + ") with splitting;");
        print("           this keeps about 120-145 non-cell particles per 144 cells at 50 um^2.");
    } else {
        print("  Method:  Niblack or Mean local threshold, radius " + radiusPx + ", with splitting.");
        print("  Filter:  lower area filter 100 um^2 (Tubeness was only reliable at high SNR).");
        if (snrClass == "INTERMEDIATE SNR")
            print("  Note:    your SNR lies between the two benchmarked levels; Tubeness c20 is worth trying as well, but it failed at SNR 4.3.");
    }
} else if (bgClass == "MEDIUM background") {
    print("  Method:  Niblack local threshold, radius " + radiusPx + ", with splitting.");
    print("  Filter:  lower area filter 100 um^2.");
    print("  Alternative: Huang global threshold with splitting (similar score at the lower end of this range, fewer non-cell particles).");
    print("  Avoid:   Tubeness (score fell to about zero by the third benchmark background and at low SNR).");
} else {
    print("  No tested method recovered cells reliably (benchmark score <= 0.11; ramified and rod recall <= 0.12).");
    print("  Improve the image first if possible (acquisition, background subtraction; not tested here).");
    print("  If it must be analysed: Niblack local threshold, radius " + radiusPx + ", with splitting, lower area filter 130-150 um^2.");
    print("  Interpret ramified and rod counts with caution.");
}
if (calibrated) {
    print("");
    print("Area filters in pixels at your pixel size: 50 um^2 = " + round(50 / (pw * ph)) + " px, 100 um^2 = "
        + round(100 / (pw * ph)) + " px, 130 um^2 = " + round(130 / (pw * ph)) + " px, 150 um^2 = " + round(150 / (pw * ph)) + " px.");
}

// ----------------------------- results table ---------------------------------
row = nResults;
setResult("Image", row, origTitle);
setResult("N_cell_regions", row, cellIdx.length);
setResult("N_bg_regions", row, bgIdx.length);
setResult("Median_cell", row, medCell);
setResult("Median_background", row, medBg);
setResult("Noise_SD", row, noiseSD);
setResult("Contrast_ratio", row, contrast);
setResult("SNR", row, snr);
setResult("Background_class", row, bgClass);
setResult("SNR_class", row, snrClass);
setResult("Saturated_fraction", row, satFrac);
updateResults();

// ----------------------------- clean up --------------------------------------
selectImage(rawID);   close();
selectImage(noiseID); close();
selectImage(devID);   close();
selectImage(origID);
roiManager("Show All");
showMessage("Image quality check",
    "Contrast ratio: " + d2s(contrast, 2) + "   SNR: " + d2s(snr, 1) + "\n"
    + bgClass + ", " + snrClass + "\n\nSee the Log window for suggested settings and warnings.");

// =============================================================================
// functions
// =============================================================================

// Ask the user to draw n regions on the original image; returns their ROI Manager indices
function collectRegions(label, n, tool, message) {
    idx = newArray(0);
    for (k = 1; k <= n; k++) {
        selectImage(origID);
        run("Select None");
        setTool(tool);
        waitForUser(label + " region " + k + " of " + n, message);
        if (selectionType() == -1) {
            if (getBoolean("No region was drawn. Finish adding " + label + " regions?")) {
                k = n + 1;
            } else {
                k--;
            }
        } else {
            roiManager("add");
            i0 = roiManager("count") - 1;
            roiManager("select", i0);
            roiManager("rename", label + "_" + (idx.length + 1));
            roiManager("deselect");
            idx = Array.concat(idx, i0);
            selectImage(origID);
            run("Select None");
        }
    }
    return idx;
}

// Duplicate the current plane/channel of the original image; returns the new image ID
function getPlane(title) {
    selectImage(origID);
    run("Select None");
    if (Stack.isHyperstack) {
        Stack.getPosition(ch, sl, fr);
        run("Duplicate...", "title=" + title + " duplicate channels=" + ch + " slices=" + sl + " frames=" + fr);
    } else if (nSlices > 1) {
        s = getSliceNumber();
        run("Duplicate...", "title=" + title + " duplicate range=" + s + "-" + s);
    } else {
        run("Duplicate...", "title=" + title);
    }
    return getImageID();
}

// Median, mean, SD and area of the pooled pixels of the given ROI Manager entries on an image
function pooledStats(imgID, idx) {
    selectImage(imgID);
    roiManager("deselect");
    if (idx.length == 1) {
        roiManager("select", idx[0]);
    } else {
        roiManager("select", idx);
        roiManager("combine");
    }
    List.setMeasurements;
    // List.getValue can come back as text in some ImageJ versions; force numbers
    out = newArray(4);
    out[0] = parseFloat("" + List.getValue("Median"));
    out[1] = parseFloat("" + List.getValue("Mean"));
    out[2] = parseFloat("" + List.getValue("StdDev"));
    out[3] = parseFloat("" + List.getValue("Area"));
    run("Select None");
    return out;
}

// Median of one ROI Manager entry on an image
function roiMedian(imgID, ri) {
    selectImage(imgID);
    roiManager("deselect");
    roiManager("select", ri);
    List.setMeasurements;
    m = parseFloat("" + List.getValue("Median"));
    run("Select None");
    return m;
}

// Fraction of pixels equal to the image maximum (8- and 16-bit only)
function saturationFraction() {
    bd = bitDepth();
    if (bd != 8 && bd != 16) return 0;
    getStatistics(area, mean, mn, mx);
    nb = 256;
    if (bd == 16) nb = 65536;
    getHistogram(vals, counts, nb);
    w = getWidth(); h = getHeight();
    if (mx >= nb) return 0;
    return counts[mx] / (w * h);
}
