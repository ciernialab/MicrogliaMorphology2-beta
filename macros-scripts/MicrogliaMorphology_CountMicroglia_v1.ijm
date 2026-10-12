// =============================================================================
// MicrogliaMorphology_CountMicroglia_v1.ijm
//
// Counts microglia using a microglia channel (Iba1) and a nuclear channel (DAPI).
// Each DAPI nucleus is a seed. A nucleus is counted as a microglia when it sits
// inside, or touches, an Iba1 cell body (soma).
//
// INPUT
//   Multi-channel TIF (hyperstack). Z-stacks are max projected per channel.
//   Pixel size is read from the image calibration. If the image has none, the
//   macro uses the fallback value from the dialog, or asks for it.
//
// MODES
//   Single image : uses the image that is open now. Interactive steps (drawing
//                  ROIs, marking cells) are available.
//   Batch        : every .tif / .tiff in a folder. Results go to a subfolder
//                  "CountMicroglia_output".
//
// REGIONS (counts are reported per region)
//   Whole image, ROIs saved in the TIF (selection and/or overlay), an ROI .zip
//   next to the image (NAME.zip, NAME_RoiSet.zip, NAME_ROI.zip, NAME_ROIs.zip or
//   RoiSet.zip), or ROIs drawn now (single image mode). If an image has no ROI,
//   the whole image is counted, or the image is skipped (dialog option).
//   A nucleus belongs to an ROI when its centroid lies inside the ROI.
//   Segmentation is done on the whole image, so thresholds do not depend on the ROI.
//
// METHOD
//   1. Nuclei: smooth, subtract background, auto threshold, fill holes, optional
//      distance-transform watershed to split touching nuclei, size filter.
//   2. Iba1: smooth, subtract background, auto threshold, close small gaps,
//      fill SMALL holes (a nucleus is a hole in the Iba1 ring), open to remove
//      thin processes (leaves somata), dilate slightly so "touching" counts.
//   3. For every nucleus: Soma_overlap = fraction of its area inside the soma
//      mask, and Iba1_on_nucleus = mean smoothed, background-subtracted Iba1
//      over the nucleus. Counted as microglia when Soma_overlap >= Min_overlap
//      AND Iba1_on_nucleus >= Iba1_k x (Iba1 threshold). A nucleus enclosed by
//      Iba1 processes but without Iba1 signal on it is rejected.
//      Optionally only one nucleus per connected soma mask is kept (the one
//      with the highest Iba1); the others are listed with Reason = Shared_soma.
//   4. Counts per region, area (mm2) and density (cells/mm2).
//
// VALIDATION (optional)
//   Hand-marked cells are multi-point clicks, one per microglia. Sources:
//     * points stored with the image or in the ROI .zip (multi-point ROI),
//     * a file NAME_marks.csv (columns X,Y in pixels of the max projection)
//       next to the image,
//     * marking now (single image mode; saved to NAME_marks.csv for batch reuse).
//   A mark matches a counted nucleus if it lies within the nucleus radius or
//   within "match distance" of its centroid (each nucleus matches once).
//   Reported per region: marks, TP, FP, FN, FN with a rejected nucleus,
//   FN with no nucleus found, precision, recall, F1.
//
// OUTPUT (folder CountMicroglia_output)
//   CountMicroglia_Summary.csv  one row per image and region (batch)
//   NAME_summary.csv            same, single image mode
//   NAME_nuclei.csv             one row per nucleus (area, soma overlap, class, region)
//   NAME_QC.png                 Iba1 green, DAPI blue; counted nuclei red, rejected
//                               nuclei yellow, soma mask white, ROIs magenta
//   NAME_nucmask.tif, NAME_somamask.tif   (optional)
//   CountMicroglia_Settings.txt all parameters used
//
// DEBUGGING
//   Tick "Verbose log". The Log shows each step with a time stamp, and the
//   variable cur_step holds the last step started, so an error message plus the
//   debugger variable dump shows where it stopped.
//
// LIMITS
//   * Max projection can merge nuclei at different depths, and a microglia whose
//     nucleus is not in the DAPI projection cannot be counted.
//   * Only the first time point is used for time series.
//   * Untested until you run it. Check the QC image first, then tune the
//     threshold multipliers and Min_overlap.
// =============================================================================

requires("1.53k");

// ----------------------------- settings (globals) ----------------------------
var run_batch = 0;          // 0 single image, 1 batch
var mic_ch = 2;
var nuc_ch = 1;
var ch_as_slices = false;
var roi_src = 1;            // 0 whole image, 1 in image, 2 zip, 3 draw now
var skip_noroi = false;
var val_mode = 0;           // 0 none, 1 existing marks, 2 mark now
var fallback_um = 0;
var show_adv = false;
var save_qc = true;
var save_masks = false;
var verbose = false;

var nuc_min_um2 = 15;       // smaller particles are ignored
var nuc_big_um2 = 200;      // larger nuclei are flagged (possible merged nuclei)
var nuc_smooth_um = 0.5;
var nuc_bg_um = 15;         // rolling ball radius, 0 = off
var nuc_method = "Li";
var nuc_mult = 1;           // multiplies the automatic lower threshold
var nuc_split = true;

var mic_smooth_um = 1;
var mic_bg_um = 25;         // rolling ball radius, 0 = off (keep larger than a soma)
var mic_method = "Huang";
var mic_mult = 1.4;
var close_um = 1.5;         // closes gaps in the Iba1 ring around a nucleus
var hole_um2 = 120;         // holes up to this area are filled
var open_um = 3.5;          // removes processes thinner than twice this value
var touch_um = 0.5;         // soma mask is dilated by this much before scoring
var min_overlap = 0.65;     // fraction of nucleus inside soma mask to count it
var iba_k = 2;              // mean Iba1 over the nucleus must be >= this x Iba1 threshold
var one_per_soma = true;    // keep only one nucleus (highest Iba1) per connected soma mask
var match_um = 6;           // validation matching distance

// ----------------------------- state (globals) -------------------------------
var SUMT = "CountMicroglia_Summary";
var NUCT = "CM_Nuclei";
var t0 = 0;
var cur_step = "";
var cur_title = "";
var cur_base = "";
var out_dir = "";
var sum_row = 0;
var pw_um = 0.3447;
var px_source = "";
var warn_text = "";
var img_w = 0;
var img_h = 0;
var reg_n = 0;
var reg_whole = true;
var reg_name = newArray(0);
var reg_area_px = newArray(0);
var reg_ntot = newArray(0);
var reg_nmic = newArray(0);
var reg_nbig = newArray(0);
var pt_x = newArray(0);
var pt_y = newArray(0);
var mk_x = newArray(0);
var mk_y = newArray(0);
var nuc_x = newArray(0);
var nuc_y = newArray(0);
var nuc_a = newArray(0);
var nuc_ov = newArray(0);
var nuc_mic = newArray(0);
var nuc_big = newArray(0);
var in_reg = newArray(0);
var nuc_thr = 0;
var mic_thr = 0;
var nuc_fg = 0;
var mic_fg = 0;
var last_lo = 0;
var have_val = false;
var v_marks = newArray(0);
var v_tp = newArray(0);
var v_fp = newArray(0);
var v_fn = newArray(0);
var v_fnrej = newArray(0);
var v_fnnone = newArray(0);
var id_orig = 0;
var micint_id = 0;
var nuc_iba = newArray(0);
var nuc_comp = newArray(0);
var nuc_why = newArray(0);
var reg_ndrop = newArray(0);
var nuc_matched = newArray(0);
var mk_matched = newArray(0);

// =============================================================================
// main
// =============================================================================
print("\\Clear");
t0 = getTime();
setOption("BlackBackground", true);

run("Set Measurements...", "area redirect=None decimal=3");
loadPrefs();
if (!showDialogs()) exit("Cancelled.");
savePrefs();

if (run_batch == 1 && roi_src == 3) exit("Drawing ROIs is only available in single image mode.");
if (run_batch == 1 && val_mode == 2) exit("Marking cells now is only available in single image mode. Use saved marks (NAME_marks.csv) for batch.");

Table.create(SUMT);
sum_row = 0;

if (run_batch == 0) {
	if (nImages == 0) exit("Open a multi-channel image first, then run the macro again.");
	id0 = getImageID();
	imgDir = getInfo("image.directory");
	if (imgDir == "") {
		out_dir = getDirectory("Choose an output folder");
	} else {
		out_dir = imgDir + "CountMicroglia_output" + File.separator;
	}
	File.makeDirectory(out_dir);
	writeSettings();
	ok = processImage(id0, getTitle(), imgDir);
	cleanTemp();
	if (ok == 1) {
		Table.update(SUMT);
		Table.save(out_dir + cur_base + "_summary.csv", SUMT);
	}
} else {
	inDir = getDirectory("Choose the folder of multi-channel TIF images");
	out_dir = inDir + "CountMicroglia_output" + File.separator;
	File.makeDirectory(out_dir);
	writeSettings();
	list = getFileList(inDir);
	nDone = 0;
	nSkip = 0;
	setBatchMode(true);
	for (f = 0; f < list.length; f++) {
		lower = toLowerCase(list[f]);
		if (endsWith(lower, ".tif") || endsWith(lower, ".tiff")) {
			open(inDir + list[f]);
			idb = getImageID();
			ok = processImage(idb, list[f], inDir);
			cleanTemp();
			if (isOpen(idb)) {
				selectImage(idb);
				close();
			}
			if (ok == 1) nDone++; else nSkip++;
			if (sum_row > 0) {
				Table.update(SUMT);
				Table.save(out_dir + "CountMicroglia_Summary.csv", SUMT);
			}
		}
	}
	setBatchMode(false);
	print("");
	print("Batch finished: " + nDone + " image(s) counted, " + nSkip + " skipped.");
}

print("Output folder: " + out_dir);
print("Total time: " + d2s((getTime() - t0) / 1000, 1) + " s");

// =============================================================================
// per-image processing
// =============================================================================
// Returns 1 when the image was counted, 0 when skipped.
function processImage(origID, title, imgDir) {
	cleanTemp();
	id_orig = origID;
	cur_title = title;
	cur_base = stripExt(title);
	warn_text = "";
	step("start " + title);

	selectImage(origID);
	if (ch_as_slices) {
		getDimensions(w0, h0, c0, z0, t1);
		if (c0 == 1 && z0 >= 2) {
			run("Stack to Hyperstack...", "order=xyczt(default) channels=" + z0 + " slices=1 frames=1 display=Color");
		}
	}
	getDimensions(img_w, img_h, nC, nZ, nT);
	if (nC < 2) {
		print("SKIPPED " + title + ": only " + nC + " channel(s) found. Tick the 'channels are slices' option if channels are stored as a plain stack.");
		return 0;
	}
	if (mic_ch > nC || nuc_ch > nC) {
		print("SKIPPED " + title + ": the image has " + nC + " channels, but channels " + mic_ch + " and " + nuc_ch + " were requested.");
		return 0;
	}
	if (nT > 1) warn_text = warn_text + "time series: first frame used; ";
	pw_um = pixelSizeUm(origID);
	step("image " + img_w + " x " + img_h + ", C=" + nC + " Z=" + nZ + ", pixel " + d2s(pw_um, 4) + " um (" + px_source + ")");

	// regions stored with the file are collected before any duplicate is made
	roiManager("reset");
	if (roi_src == 1) harvestFromImage(origID);
	if (roi_src == 2) harvestFromZip(imgDir);

	step("channel planes");
	micID = getChannelPlane(origID, mic_ch, "CM_mic");
	nucID = getChannelPlane(origID, nuc_ch, "CM_nuc");
	baseID = makeBaseRGB(micID, nucID);
	newImage("CM_roiholder", "8-bit black", img_w, img_h, 1);
	holderID = getImageID();

	if (roi_src == 3) drawRegions(baseID);

	step("regions");
	nFound = finalizeRegions(baseID, holderID);
	if (nFound == 0 && skip_noroi && roi_src != 0) {
		print("SKIPPED " + title + ": no ROI found.");
		return 0;
	}
	if (nFound == 0 && roi_src != 0) warn_text = warn_text + "no ROI found, whole image counted; ";
	computeRegionAreas(holderID);

	// hand-marked cells
	mk_x = newArray(0);
	mk_y = newArray(0);
	have_val = false;
	if (val_mode == 1) {
		mk_x = pt_x;
		mk_y = pt_y;
		nCsv = loadMarksCSV(imgDir + cur_base + "_marks.csv");
		step("existing marks: " + pt_x.length + " from ROI file, " + nCsv + " from CSV");
	}
	if (val_mode == 2) markNow(baseID, imgDir);
	if (val_mode > 0) {
		if (mk_x.length > 0) {
			have_val = true;
		} else {
			print("No hand-marked cells found for " + title + ". Validation skipped for this image.");
			warn_text = warn_text + "no marks found; ";
		}
	}

	step("segment nuclei");
	nucMaskID = segmentNuclei(nucID);
	step("build soma mask");
	somaID = buildSoma(micID);
	step("measure nuclei");
	measureNuclei(nucMaskID, somaID);
	n = nuc_x.length;
	if (n == 0) warn_text = warn_text + "no nuclei found; ";
	if (nuc_fg > 0.4) warn_text = warn_text + "nuclear mask covers " + d2s(100 * nuc_fg, 0) + "% of the image (threshold too low?); ";
	if (mic_fg > 0.6) warn_text = warn_text + "Iba1 mask covers " + d2s(100 * mic_fg, 0) + "% of the image (threshold too low?); ";
	if (mic_fg < 0.005) warn_text = warn_text + "Iba1 mask is nearly empty (threshold too high?); ";

	step("assign nuclei to regions");
	assignRegions(holderID);
	countRegions();
	if (have_val) {
		step("validation");
		validateMarks(holderID);
	}

	step("write tables");
	writeTables();

	step("QC image");
	buildQC(baseID, holderID, somaID);

	if (save_masks) {
		selectImage(nucMaskID);
		saveAs("Tiff", out_dir + cur_base + "_nucmask.tif");
		selectImage(somaID);
		saveAs("Tiff", out_dir + cur_base + "_somamask.tif");
	}

	printReport();
	step("done " + title);
	return 1;
}

// =============================================================================
// segmentation
// =============================================================================
function segmentNuclei(nucID) {
	selectImage(nucID);
	run("Duplicate...", "title=CM_nuc_work");
	run("32-bit");
	if (nuc_smooth_um > 0) run("Gaussian Blur...", "sigma=" + d2s(nuc_smooth_um / pw_um, 3));
	if (nuc_bg_um > 0) run("Subtract Background...", "rolling=" + d2s(nuc_bg_um / pw_um, 1));
	id = thresholdToMask(getImageID(), nuc_method, nuc_mult, "CM_nucmask");
	nuc_thr = last_lo;
	selectImage(id);
	run("Fill Holes");
	if (nuc_split) run("Watershed");
	nuc_fg = fgFraction();
	step("nuclear threshold " + d2s(nuc_thr, 3) + ", foreground " + d2s(100 * nuc_fg, 1) + "%");
	return id;
}

function buildSoma(micID) {
	selectImage(micID);
	run("Duplicate...", "title=CM_mic_work");
	run("32-bit");
	if (mic_smooth_um > 0) run("Gaussian Blur...", "sigma=" + d2s(mic_smooth_um / pw_um, 3));
	if (mic_bg_um > 0) run("Subtract Background...", "rolling=" + d2s(mic_bg_um / pw_um, 1));
	workID = getImageID();
	run("Duplicate...", "title=CM_micint");
	micint_id = getImageID();
	micMaskID = thresholdToMask(workID, mic_method, mic_mult, "CM_micmask");
	mic_thr = last_lo;
	selectImage(micMaskID);
	mic_fg = fgFraction();

	run("Duplicate...", "title=CM_soma");
	somaID = getImageID();
	// close gaps in the Iba1 ring, fill small holes (the nucleus), remove thin processes
	if (close_um > 0) {
		run("Maximum...", "radius=" + d2s(close_um / pw_um, 1));
		run("Minimum...", "radius=" + d2s(close_um / pw_um, 1));
	}
	fillSmallHoles(somaID, hole_um2 / (pw_um * pw_um));
	selectImage(somaID);
	if (open_um > 0) {
		run("Minimum...", "radius=" + d2s(open_um / pw_um, 1));
		run("Maximum...", "radius=" + d2s(open_um / pw_um, 1));
	}
	if (touch_um > 0) run("Maximum...", "radius=" + d2s(touch_um / pw_um, 1));
	resetThreshold();
	step("Iba1 threshold " + d2s(mic_thr, 3) + ", Iba1 foreground " + d2s(100 * mic_fg, 1) + "%, soma mask " + d2s(100 * fgFraction(), 1) + "%");

	selectImage(micMaskID);
	close();
	return somaID;
}

// Measures every nucleus, with the soma mask as the redirect image.
// The nuclei stay in the ROI Manager (same order as the arrays).
function measureNuclei(nucMaskID, somaID) {
	selectImage(somaID);
	resetThreshold();
	run("Set Measurements...", "area centroid mean redirect=CM_soma decimal=3");
	roiManager("reset");
	selectImage(nucMaskID);
	setThreshold(255, 255);
	minPx = nuc_min_um2 / (pw_um * pw_um);
	run("Analyze Particles...", "size=" + d2s(minPx, 1) + "-Infinity pixel show=Nothing display clear add");
	resetThreshold();
	n = nResults;
	nuc_x = newArray(n);
	nuc_y = newArray(n);
	nuc_a = newArray(n);
	nuc_ov = newArray(n);
	nuc_mic = newArray(n);
	nuc_big = newArray(n);
	nuc_why = newArray(n);
	for (j = 0; j < n; j++) {
		nuc_a[j] = parseFloat("" + getResult("Area", j)) * pw_um * pw_um;
		nuc_x[j] = parseFloat("" + getResult("X", j));
		nuc_y[j] = parseFloat("" + getResult("Y", j));
		nuc_ov[j] = parseFloat("" + getResult("Mean", j)) / 255;
		if (nuc_a[j] > nuc_big_um2) nuc_big[j] = 1;
	}
	if (roiManager("count") != n) warn_text = warn_text + "ROI Manager count (" + roiManager("count") + ") differs from nuclei (" + n + "); ";

	// mean Iba1 signal (smoothed, background subtracted) over each nucleus
	nuc_iba = newArray(n);
	if (n > 0) {
		run("Set Measurements...", "mean redirect=CM_micint decimal=3");
		run("Clear Results");
		selectImage(nucMaskID);
		roiManager("deselect");
		roiManager("Measure");
		if (nResults == n) {
			for (j = 0; j < n; j++) nuc_iba[j] = parseFloat("" + getResult("Mean", j));
		} else {
			warn_text = warn_text + "Iba1 on nucleus not measured (" + nResults + " rows for " + n + " nuclei); ";
		}
	}
	run("Set Measurements...", "area redirect=None decimal=3");
	somaComponents(somaID);

	// decision
	cand = newArray(n);
	maxC = 0;
	for (j = 0; j < n; j++) {
		nuc_why[j] = "Microglia";
		if (nuc_ov[j] < min_overlap) nuc_why[j] = "Low_soma_overlap";
		else if (nuc_iba[j] < iba_k * mic_thr) nuc_why[j] = "Low_Iba1_on_nucleus";
		if (nuc_why[j] == "Microglia") cand[j] = 1;
		if (nuc_comp[j] > maxC) maxC = nuc_comp[j];
	}
	bestOf = newArray(maxC + 1);
	Array.fill(bestOf, -1);
	if (one_per_soma) {
		for (j = 0; j < n; j++) {
			if (cand[j] == 1) {
				c = nuc_comp[j];
				if (c > 0) {
					if (bestOf[c] < 0) bestOf[c] = j;
					else if (nuc_iba[j] > nuc_iba[bestOf[c]]) bestOf[c] = j;
				}
			}
		}
	}
	for (j = 0; j < n; j++) {
		if (cand[j] == 1) {
			keep = 1;
			if (one_per_soma) {
				c = nuc_comp[j];
				if (c > 0) {
					if (bestOf[c] != j) keep = 0;
				}
			}
			if (keep == 1) nuc_mic[j] = 1;
			else nuc_why[j] = "Shared_soma";
		}
	}
	nm = 0;
	nsh = 0;
	for (j = 0; j < n; j++) {
		nm = nm + nuc_mic[j];
		if (nuc_why[j] == "Shared_soma") nsh++;
	}
	step("nuclei " + n + ", counted as microglia " + nm + ", dropped as sharing a soma mask " + nsh);
}

// Connected soma-mask component (1, 2, ...) under each nucleus centroid; 0 = none.
function somaComponents(somaID) {
	n = nuc_x.length;
	nuc_comp = newArray(n);
	if (n == 0) return 0;
	selectImage(somaID);
	setThreshold(255, 255);
	run("Analyze Particles...", "size=0-Infinity pixel show=[Count Masks] clear");
	lid = getImageID();
	if (lid == somaID) {
		warn_text = warn_text + "soma components not labelled; ";
		resetThreshold();
		return 0;
	}
	for (j = 0; j < n; j++) {
		px = minOf(img_w - 1, maxOf(0, round(nuc_x[j])));
		py = minOf(img_h - 1, maxOf(0, round(nuc_y[j])));
		nuc_comp[j] = getPixel(px, py);
	}
	selectImage(lid);
	close();
	selectImage(somaID);
	resetThreshold();
	return 1;
}

// Auto threshold a 32-bit image and convert it to a 0/255 mask (255 = foreground).
function thresholdToMask(id, method, mult, newTitle) {
	selectImage(id);
	resetThreshold();
	setAutoThreshold(method + " dark");
	getThreshold(lo, hi);
	getStatistics(area, mean, mn, mx);
	if (mult != 1) {
		lo = lo * mult;
		setThreshold(lo, mx);
	}
	last_lo = lo;
	run("Convert to Mask");
	rename(newTitle);
	ensureNormalLUT();
	return getImageID();
}

// Fill background holes up to maxPx pixels that are enclosed by foreground.
function fillSmallHoles(maskID, maxPx) {
	selectImage(maskID);
	run("Duplicate...", "title=CM_inv");
	invID = getImageID();
	run("Invert");
	setThreshold(255, 255);
	// Set Measurements is remembered between runs; clear any redirect left by the last run
	run("Set Measurements...", "area redirect=None decimal=3");
	run("Analyze Particles...", "size=0-" + d2s(maxPx, 1) + " pixel show=Masks exclude");
	holesID = getImageID();
	if (holesID == invID) {
		warn_text = warn_text + "hole filling produced no mask image; ";
		selectImage(invID);
		close();
		return 0;
	}
	ensureNormalLUT();
	imageCalculator("OR", maskID, holesID);
	selectImage(holesID);
	close();
	selectImage(invID);
	close();
	selectImage(maskID);
	return 1;
}

function ensureNormalLUT() {
	if (is("Inverting LUT")) run("Invert LUT");
}

function fgFraction() {
	getStatistics(a, m);
	return m / 255;
}

// =============================================================================
// image preparation
// =============================================================================
// Max projected plane of one channel, original bit depth, no calibration.
function getChannelPlane(srcID, ch, title) {
	selectImage(srcID);
	run("Select None");
	getDimensions(w, h, nC, nZ, nT);
	run("Duplicate...", "title=CM_tmp duplicate channels=" + ch + " slices=1-" + nZ + " frames=1");
	tmp = getImageID();
	if (nSlices > 1) {
		run("Z Project...", "projection=[Max Intensity]");
		zp = getImageID();
		selectImage(tmp);
		close();
		selectImage(zp);
	}
	rename(title);
	run("Set Scale...", "distance=0 known=0 unit=pixel");
	return getImageID();
}

// RGB image: Iba1 green, DAPI blue (contrast stretched copies).
function makeBaseRGB(micID, nucID) {
	selectImage(micID);
	run("Duplicate...", "title=CM_g");
	run("Enhance Contrast...", "saturated=0.35 normalize");
	run("8-bit");
	selectImage(nucID);
	run("Duplicate...", "title=CM_b");
	run("Enhance Contrast...", "saturated=0.35 normalize");
	run("8-bit");
	run("Merge Channels...", "c2=CM_g c3=CM_b");
	rename("CM_base");
	return getImageID();
}

// Pixel size in um. Uses the calibration, else the fallback value, else asks.
function pixelSizeUm(id) {
	selectImage(id);
	getPixelSize(unit, pwx, phx);
	u = toLowerCase(unit);
	f = 0;
	if (u == "um" || u == "micron" || u == "microns" || u == fromCharCode(181) + "m" || u == fromCharCode(956) + "m") f = 1;
	if (u == "nm") f = 0.001;
	if (u == "mm") f = 1000;
	if (u == "cm") f = 10000;
	if (f > 0 && pwx > 0) {
		px_source = "metadata";
		return pwx * f;
	}
	if (fallback_um <= 0) {
		Dialog.create("Pixel size needed");
		Dialog.addMessage("The image " + getTitle() + " has no calibration in microns (unit: " + unit + ").");
		Dialog.addNumber("Pixel size:", 0.3447, 4, 8, "um per pixel");
		Dialog.show();
		fallback_um = Dialog.getNumber();
		if (fallback_um <= 0) exit("A pixel size greater than zero is needed.");
	}
	px_source = "fallback";
	warn_text = warn_text + "pixel size from fallback value; ";
	return fallback_um;
}

// =============================================================================
// regions and marks
// =============================================================================
// Selection and overlay of the opened image go to the ROI Manager.
function harvestFromImage(origID) {
	selectImage(origID);
	if (Overlay.size > 0) run("To ROI Manager");
	selectImage(origID);
	if (selectionType() != -1) roiManager("add");
}

function harvestFromZip(imgDir) {
	if (imgDir == "") return 0;
	cands = newArray(cur_base + ".zip", cur_base + "_RoiSet.zip", cur_base + "_ROI.zip", cur_base + "_ROIs.zip", "RoiSet.zip");
	for (k = 0; k < cands.length; k++) {
		p = imgDir + cands[k];
		if (File.exists(p)) {
			roiManager("open", p);
			step("ROI file " + cands[k] + ": " + roiManager("count") + " ROI(s)");
			return 1;
		}
	}
	return 0;
}

// Interactive ROI drawing on the projection (single image mode).
function drawRegions(baseID) {
	k = 1;
	more = true;
	while (more) {
		selectImage(baseID);
		run("Select None");
		setTool("freehand");
		waitForUser("Draw ROI " + k, "Draw ROI " + k + " (freehand, polygon, rectangle or oval) on the image, then click OK.\nClick OK without a selection to count the whole image.");
		if (selectionType() == -1) {
			more = false;
		} else {
			roiManager("add");
			k++;
			more = getBoolean("ROI added. Draw another ROI?");
		}
	}
	selectImage(baseID);
	run("Select None");
}

// Splits the ROI Manager content into area ROIs (regions) and points (marks).
// Returns the number of area ROIs found. Area ROIs end up as the overlay of the
// holder image; index r of the overlay is region r.
function finalizeRegions(baseID, holderID) {
	pt_x = newArray(0);
	pt_y = newArray(0);
	reg_name = newArray(0);
	nIn = roiManager("count");
	delIdx = newArray(0);
	selectImage(baseID);
	for (i = 0; i < nIn; i++) {
		roiManager("select", i);
		t = selectionType();
		if (t == 10) {
			getSelectionCoordinates(xs, ys);
			pt_x = Array.concat(pt_x, xs);
			pt_y = Array.concat(pt_y, ys);
			delIdx = Array.concat(delIdx, i);
		} else if ((t >= 0 && t <= 4) || t == 9) {
			nm = "" + call("ij.plugin.frame.RoiManager.getName", "" + i);
			if (nm == "" || nm == "null") nm = "ROI_" + (reg_name.length + 1);
			reg_name = Array.concat(reg_name, nm);
		} else {
			print("Skipped ROI " + (i + 1) + " (selection type " + t + " is not an area or point ROI).");
			delIdx = Array.concat(delIdx, i);
		}
	}
	roiManager("deselect");
	if (delIdx.length > 0) {
		selectIdx(delIdx);
		roiManager("delete");
	}
	found = roiManager("count");
	reg_n = found;
	reg_whole = (found == 0);
	if (found > 0) {
		selectImage(baseID);
		roiManager("deselect");
		run("From ROI Manager");
		selectImage(holderID);
		run("From ROI Manager");
	}
	roiManager("reset");
	if (reg_whole) {
		reg_n = 1;
		reg_name = newArray("Whole_image");
	}
	step("regions: " + found + " ROI(s), " + pt_x.length + " point(s)");
	return found;
}

function computeRegionAreas(holderID) {
	reg_area_px = newArray(reg_n);
	for (r = 0; r < reg_n; r++) {
		if (reg_whole) {
			reg_area_px[r] = img_w * img_h;
		} else {
			selectImage(holderID);
			Overlay.activateSelection(r);
			List.setMeasurements;
			reg_area_px[r] = parseFloat("" + List.getValue("Area"));
			run("Select None");
		}
	}
}

function markNow(baseID, imgDir) {
	selectImage(baseID);
	run("Select None");
	setTool("multipoint");
	waitForUser("Mark microglia", "Click once on every microglia in the region(s) you want to validate\n(a cell with a DAPI nucleus inside or touching an Iba1 cell body).\nIf you use ROIs, mark only inside them. Then click OK.");
	mk_x = newArray(0);
	mk_y = newArray(0);
	if (selectionType() == 10) {
		getSelectionCoordinates(xs, ys);
		mk_x = xs;
		mk_y = ys;
	}
	run("Select None");
	if (mk_x.length > 0) {
		p = imgDir + cur_base + "_marks.csv";
		if (imgDir == "") p = out_dir + cur_base + "_marks.csv";
		s = "X,Y\n";
		for (q = 0; q < mk_x.length; q++) s = s + d2s(mk_x[q], 2) + "," + d2s(mk_y[q], 2) + "\n";
		File.saveString(s, p);
		print(mk_x.length + " cells marked. Saved to " + p);
	}
}

function loadMarksCSV(p) {
	if (!File.exists(p)) return 0;
	s = File.openAsString(p);
	lines = split(s, "\n\r");
	cnt = 0;
	for (i = 0; i < lines.length; i++) {
		fld = split(lines[i], ",");
		if (fld.length >= 2) {
			x = parseFloat(fld[0]);
			y = parseFloat(fld[1]);
			if (!isNaN(x) && !isNaN(y)) {
				mk_x = Array.concat(mk_x, x);
				mk_y = Array.concat(mk_y, y);
				cnt++;
			}
		}
	}
	return cnt;
}

// =============================================================================
// counting and validation
// =============================================================================
function assignRegions(holderID) {
	n = nuc_x.length;
	in_reg = newArray(reg_n * n);
	for (r = 0; r < reg_n; r++) {
		if (reg_whole) {
			for (j = 0; j < n; j++) in_reg[r * n + j] = 1;
		} else {
			selectImage(holderID);
			Overlay.activateSelection(r);
			for (j = 0; j < n; j++) {
				if (selectionContains(nuc_x[j], nuc_y[j])) in_reg[r * n + j] = 1;
			}
			run("Select None");
		}
	}
}

function countRegions() {
	n = nuc_x.length;
	reg_ntot = newArray(reg_n);
	reg_nmic = newArray(reg_n);
	reg_nbig = newArray(reg_n);
	reg_ndrop = newArray(reg_n);
	for (r = 0; r < reg_n; r++) {
		for (j = 0; j < n; j++) {
			if (in_reg[r * n + j] == 1) {
				if (nuc_why[j] == "Shared_soma") reg_ndrop[r] = reg_ndrop[r] + 1;
				reg_ntot[r] = reg_ntot[r] + 1;
				reg_nmic[r] = reg_nmic[r] + nuc_mic[j];
				reg_nbig[r] = reg_nbig[r] + nuc_big[j];
			}
		}
	}
}

function validateMarks(holderID) {
	n = nuc_x.length;
	nm = mk_x.length;
	v_marks = newArray(reg_n);
	v_tp = newArray(reg_n);
	v_fp = newArray(reg_n);
	v_fn = newArray(reg_n);
	v_fnrej = newArray(reg_n);
	v_fnnone = newArray(reg_n);
	tolMin = match_um / pw_um;
	nuc_matched = newArray(n);
	mk_matched = newArray(nm);
	if (nm > 0) Array.fill(mk_matched, -1);	// -1 = mark outside all regions
	for (r = 0; r < reg_n; r++) {
		used = newArray(n);
		mIn = newArray(0);
		if (!reg_whole) {
			selectImage(holderID);
			Overlay.activateSelection(r);
		}
		for (q = 0; q < nm; q++) {
			inside = true;
			if (!reg_whole) inside = selectionContains(mk_x[q], mk_y[q]);
			if (inside) mIn = Array.concat(mIn, q);
		}
		if (!reg_whole) run("Select None");
		tp = 0;
		fnRej = 0;
		fnNone = 0;
		for (k = 0; k < mIn.length; k++) {
			q = mIn[k];
			best = -1;
			bestD = 1e30;
			for (j = 0; j < n; j++) {
				if (in_reg[r * n + j] == 1 && nuc_mic[j] == 1 && used[j] == 0) {
					d = sqrt(pow(mk_x[q] - nuc_x[j], 2) + pow(mk_y[q] - nuc_y[j], 2));
					tol = maxOf(tolMin, sqrt(nuc_a[j] / PI) / pw_um);
					if (d <= tol && d < bestD) {
						best = j;
						bestD = d;
					}
				}
			}
			mk_matched[q] = 0;
			if (best >= 0) {
				used[best] = 1;
				nuc_matched[best] = 1;
				mk_matched[q] = 1;
				tp++;
			} else {
				rej = 0;
				for (j = 0; j < n; j++) {
					if (in_reg[r * n + j] == 1 && nuc_mic[j] == 0) {
						d = sqrt(pow(mk_x[q] - nuc_x[j], 2) + pow(mk_y[q] - nuc_y[j], 2));
						tol = maxOf(tolMin, sqrt(nuc_a[j] / PI) / pw_um);
						if (d <= tol) rej = 1;
					}
				}
				if (rej == 1) fnRej++; else fnNone++;
			}
		}
		v_marks[r] = mIn.length;
		v_tp[r] = tp;
		v_fn[r] = fnRej + fnNone;
		v_fnrej[r] = fnRej;
		v_fnnone[r] = fnNone;
		v_fp[r] = reg_nmic[r] - tp;
	}
}

// =============================================================================
// tables, QC, report
// =============================================================================
function writeTables() {
	n = nuc_x.length;
	Table.create(NUCT);
	for (j = 0; j < n; j++) {
		regs = "";
		for (r = 0; r < reg_n; r++) {
			if (in_reg[r * n + j] == 1) regs = regs + (r + 1) + ";";
		}
		if (regs == "") regs = "outside ROIs";
		if (reg_whole) regs = "whole image";
		cls = "Other";
		if (nuc_mic[j] == 1) cls = "Microglia";
		Table.set("Image", j, cur_title, NUCT);
		Table.set("Nucleus", j, j + 1, NUCT);
		Table.set("X_px", j, nuc_x[j], NUCT);
		Table.set("Y_px", j, nuc_y[j], NUCT);
		Table.set("Area_um2", j, nuc_a[j], NUCT);
		Table.set("Soma_overlap", j, nuc_ov[j], NUCT);
		Table.set("Class", j, cls, NUCT);
		Table.set("Reason", j, nuc_why[j], NUCT);
		Table.set("Iba1_on_nucleus", j, nuc_iba[j], NUCT);
		if (mic_thr > 0) Table.set("Iba1_ratio", j, nuc_iba[j] / mic_thr, NUCT);
		Table.set("Soma_component", j, nuc_comp[j], NUCT);
		Table.set("Large_flag", j, nuc_big[j], NUCT);
		Table.set("Regions", j, regs, NUCT);
	}
	Table.update(NUCT);
	if (n > 0) Table.save(out_dir + cur_base + "_nuclei.csv", NUCT);

	for (r = 0; r < reg_n; r++) {
		areaUm2 = reg_area_px[r] * pw_um * pw_um;
		areaMm2 = areaUm2 / 1000000;
		row = sum_row;
		Table.set("Image", row, cur_title, SUMT);
		Table.set("Region_index", row, r + 1, SUMT);
		Table.set("Region", row, reg_name[r], SUMT);
		Table.set("Region_area_um2", row, areaUm2, SUMT);
		Table.set("Region_area_mm2", row, areaMm2, SUMT);
		Table.set("Nuclei_total", row, reg_ntot[r], SUMT);
		Table.set("Microglia_count", row, reg_nmic[r], SUMT);
		Table.set("Other_nuclei", row, reg_ntot[r] - reg_nmic[r], SUMT);
		if (areaMm2 > 0) {
			Table.set("Microglia_per_mm2", row, reg_nmic[r] / areaMm2, SUMT);
			Table.set("Nuclei_per_mm2", row, reg_ntot[r] / areaMm2, SUMT);
		}
		if (reg_ntot[r] > 0) Table.set("Pct_nuclei_microglia", row, 100 * reg_nmic[r] / reg_ntot[r], SUMT);
		Table.set("Large_nuclei_flagged", row, reg_nbig[r], SUMT);
		Table.set("Dropped_shared_soma", row, reg_ndrop[r], SUMT);
		Table.set("Min_overlap", row, min_overlap, SUMT);
		Table.set("Iba1_k", row, iba_k, SUMT);
		Table.set("One_per_soma", row, one_per_soma, SUMT);
		Table.set("Nuc_threshold", row, nuc_thr, SUMT);
		Table.set("Iba1_threshold", row, mic_thr, SUMT);
		Table.set("Pixel_size_um", row, pw_um, SUMT);
		Table.set("Pixel_size_source", row, px_source, SUMT);
		if (have_val) {
			Table.set("Marks", row, v_marks[r], SUMT);
			Table.set("TP", row, v_tp[r], SUMT);
			Table.set("FP", row, v_fp[r], SUMT);
			Table.set("FN", row, v_fn[r], SUMT);
			Table.set("FN_nucleus_rejected", row, v_fnrej[r], SUMT);
			Table.set("FN_no_nucleus", row, v_fnnone[r], SUMT);
			if (v_tp[r] + v_fp[r] > 0) Table.set("Precision", row, v_tp[r] / (v_tp[r] + v_fp[r]), SUMT);
			if (v_tp[r] + v_fn[r] > 0) Table.set("Recall", row, v_tp[r] / (v_tp[r] + v_fn[r]), SUMT);
			if (2 * v_tp[r] + v_fp[r] + v_fn[r] > 0) Table.set("F1", row, 2 * v_tp[r] / (2 * v_tp[r] + v_fp[r] + v_fn[r]), SUMT);
		}
		Table.set("Warnings", row, warn_text, SUMT);
		sum_row++;
	}
	Table.update(SUMT);
}

// Burned-in QC picture: red = counted, yellow = rejected nuclei, white = soma mask, magenta = ROIs.
function buildQC(baseID, holderID, somaID) {
	n = nuc_x.length;
	lw = maxOf(1, round(maxOf(img_w, img_h) / 1200));
	// the nuclei are in the ROI Manager, index j = nucleus j+1
	if (n > 0 && roiManager("count") == n) {
		micIdx = newArray(0);
		fpIdx = newArray(0);
		othIdx = newArray(0);
		shrIdx = newArray(0);
		for (j = 0; j < n; j++) {
			if (nuc_mic[j] == 1) {
				if (have_val) {
					if (nuc_matched[j] == 1) micIdx = Array.concat(micIdx, j);
					else fpIdx = Array.concat(fpIdx, j);
				} else {
					micIdx = Array.concat(micIdx, j);
				}
			}
			else if (nuc_why[j] == "Shared_soma") shrIdx = Array.concat(shrIdx, j);
			else othIdx = Array.concat(othIdx, j);
		}
		roiManager("deselect");
		if (selectIdx(micIdx)) {
			roiManager("Set Color", "red");
			roiManager("Set Line Width", lw);
		}
		roiManager("deselect");
		if (selectIdx(fpIdx)) {
			roiManager("Set Color", "magenta");
			roiManager("Set Line Width", lw);
		}
		roiManager("deselect");
		if (selectIdx(othIdx)) {
			roiManager("Set Color", "yellow");
			roiManager("Set Line Width", lw);
		}
		roiManager("deselect");
		if (selectIdx(shrIdx)) {
			roiManager("Set Color", "orange");
			roiManager("Set Line Width", lw);
		}
		roiManager("deselect");
	} else if (n > 0) {
		warn_text = warn_text + "QC colours skipped (ROI Manager count mismatch); ";
		roiManager("reset");
	} else {
		roiManager("reset");
	}
	// soma mask outline
	selectImage(somaID);
	setThreshold(255, 255);
	run("Create Selection");
	if (selectionType() != -1) {
		roiManager("add");
		k = roiManager("count") - 1;
		roiManager("select", k);
		roiManager("Set Color", "lightGray");
		roiManager("Set Line Width", 1);
	}
	run("Select None");
	resetThreshold();
	// hand-marked cells: cyan circle = matched a counted nucleus, white circle = no counted nucleus
	if (have_val) {
		mr = maxOf(6, round(4 / pw_um));
		mOk = newArray(0);
		mMiss = newArray(0);
		selectImage(baseID);
		for (q = 0; q < mk_x.length; q++) {
			if (mk_matched[q] >= 0) {
				makeOval(mk_x[q] - mr, mk_y[q] - mr, 2 * mr, 2 * mr);
				roiManager("add");
				k = roiManager("count") - 1;
				if (mk_matched[q] == 1) mOk = Array.concat(mOk, k);
				else mMiss = Array.concat(mMiss, k);
			}
		}
		run("Select None");
		roiManager("deselect");
		if (selectIdx(mOk)) {
			roiManager("Set Color", "cyan");
			roiManager("Set Line Width", lw + 1);
		}
		roiManager("deselect");
		if (selectIdx(mMiss)) {
			roiManager("Set Color", "white");
			roiManager("Set Line Width", lw + 1);
		}
		roiManager("deselect");
	}
	// ROI outlines
	if (!reg_whole) {
		for (r = 0; r < reg_n; r++) {
			selectImage(holderID);
			Overlay.activateSelection(r);
			roiManager("add");
			k = roiManager("count") - 1;
			roiManager("select", k);
			roiManager("Set Color", "pink");
			roiManager("Set Line Width", lw + 1);
			selectImage(holderID);
			run("Select None");
		}
	}
	selectImage(baseID);
	run("Select None");	// a leftover selection would crop the duplicate
	run("Duplicate...", "title=CM_QC");
	qcID = getImageID();
	run("Remove Overlay");
	roiManager("deselect");
	if (roiManager("count") > 0) run("From ROI Manager");
	roiManager("Show None");
	run("Flatten");
	flatID = getImageID();
	rename("QC_" + cur_base);

	// legend
	fs = maxOf(12, round(maxOf(img_w, img_h) / 110));
	setFont("SansSerif", fs, "bold antialiased");
	setColor("white");
	y = fs + 6;
	if (have_val) {
		drawString("red: counted, has a mark   magenta: counted, NO mark   yellow: rejected   orange: dropped (shares a soma mask)", 8, y);
		y = y + fs + 4;
		drawString("cyan circle: mark matched   white circle: mark with no counted nucleus   gray outline: Iba1 soma mask" + legendRoi(), 8, y);
		tTP = 0;
		tFP = 0;
		tFN = 0;
		for (r = 0; r < reg_n; r++) {
			tTP = tTP + v_tp[r];
			tFP = tFP + v_fp[r];
			tFN = tFN + v_fn[r];
		}
		y = y + fs + 4;
		drawString("Validation: TP " + tTP + "   FP (magenta) " + tFP + "   FN (white circles) " + tFN, 8, y);
	} else {
		drawString("red: counted microglia nuclei   yellow: rejected   orange: dropped (shares a soma mask)   gray outline: Iba1 soma mask" + legendRoi(), 8, y);
	}
	for (r = 0; r < reg_n; r++) {
		if (r < 6) {
			y = y + fs + 4;
			drawString(reg_name[r] + ": " + reg_nmic[r] + " microglia of " + reg_ntot[r] + " nuclei", 8, y);
		}
	}
	if (save_qc) saveAs("PNG", out_dir + cur_base + "_QC.png");
	if (isOpen(qcID)) {
		selectImage(qcID);
		close();
	}
	if (run_batch == 1) {
		selectImage(flatID);
		close();
	}
}

function legendRoi() {
	if (reg_whole) return "";
	return "   pink: ROI";
}

function printReport() {
	print("");
	print("==== " + cur_title + " ====");
	for (r = 0; r < reg_n; r++) {
		areaMm2 = reg_area_px[r] * pw_um * pw_um / 1000000;
		line = reg_name[r] + ": " + reg_nmic[r] + " microglia of " + reg_ntot[r] + " nuclei, area " + d2s(areaMm2, 4) + " mm2";
		if (areaMm2 > 0) line = line + ", " + d2s(reg_nmic[r] / areaMm2, 0) + " microglia/mm2";
		if (have_val) line = line + " | marks " + v_marks[r] + " TP " + v_tp[r] + " FP " + v_fp[r] + " FN " + v_fn[r] + " (rejected nucleus " + v_fnrej[r] + ", no nucleus " + v_fnnone[r] + ")";
		print(line);
	}
	if (warn_text != "") print("WARNINGS: " + warn_text);
}

// =============================================================================
// helpers
// =============================================================================
function step(s) {
	cur_step = s;
	if (verbose) print("[" + d2s((getTime() - t0) / 1000, 1) + " s] " + s);
}

function stripExt(s) {
	i = lastIndexOf(s, ".");
	if (i > 0) return substring(s, 0, i);
	return s;
}

// Selects the given ROI Manager indices. Returns false when the array is empty.
function selectIdx(arr) {
	if (arr.length == 0) return false;
	if (arr.length == 1) roiManager("select", arr[0]);
	else roiManager("select", arr);
	return true;
}

function closeTitle(t) {
	if (isOpen(t)) {
		selectImage(t);
		close();
	}
}

// Closes working images left from the previous image (keeps the original and the QC picture).
function cleanTemp() {
	names = newArray("CM_mic", "CM_nuc", "CM_base", "CM_roiholder", "CM_nucmask", "CM_soma", "CM_micmask", "CM_micint", "CM_mic_work", "CM_nuc_work", "CM_inv", "CM_tmp", "CM_g", "CM_b", "CM_QC");
	for (k = 0; k < names.length; k++) closeTitle(names[k]);
}

function idxOf(arr, s) {
	for (k = 0; k < arr.length; k++) {
		if (arr[k] == s) return k;
	}
	return 0;
}

// ----------------------------- preferences -----------------------------------
function pStr(key, def) { return call("ij.Prefs.get", "CM2." + key, "" + def); }
function pNum(key, def) {
	v = parseFloat(pStr(key, def));
	if (isNaN(v)) v = def;
	return v;
}
function pSave(key, v) { call("ij.Prefs.set", "CM2." + key, "" + v); }

function loadPrefs() {
	run_batch = pNum("run_batch", 0);
	mic_ch = pNum("mic_ch", 2);
	nuc_ch = pNum("nuc_ch", 1);
	ch_as_slices = (pNum("ch_as_slices", 0) == 1);
	roi_src = pNum("roi_src", 1);
	skip_noroi = (pNum("skip_noroi", 0) == 1);
	val_mode = pNum("val_mode", 0);
	fallback_um = pNum("fallback_um", 0);
	save_qc = (pNum("save_qc", 1) == 1);
	save_masks = (pNum("save_masks", 0) == 1);
	nuc_min_um2 = pNum("nuc_min_um2", 15);
	nuc_big_um2 = pNum("nuc_big_um2", 200);
	nuc_smooth_um = pNum("nuc_smooth_um", 0.5);
	nuc_bg_um = pNum("nuc_bg_um", 15);
	nuc_method = pStr("nuc_method", "Li");
	nuc_mult = pNum("nuc_mult", 1);
	nuc_split = (pNum("nuc_split", 1) == 1);
	mic_smooth_um = pNum("mic_smooth_um", 1);
	mic_bg_um = pNum("mic_bg_um", 25);
	mic_method = pStr("mic_method", "Huang");
	mic_mult = pNum("mic_mult", 1.4);
	close_um = pNum("close_um", 1.5);
	hole_um2 = pNum("hole_um2", 120);
	open_um = pNum("open_um", 3.5);
	touch_um = pNum("touch_um", 0.5);
	min_overlap = pNum("min_overlap", 0.65);
	iba_k = pNum("iba_k", 2);
	one_per_soma = (pNum("one_per_soma", 1) == 1);
	match_um = pNum("match_um", 6);
}

function savePrefs() {
	pSave("run_batch", run_batch);
	pSave("mic_ch", mic_ch);
	pSave("nuc_ch", nuc_ch);
	pSave("ch_as_slices", ch_as_slices);
	pSave("roi_src", roi_src);
	pSave("skip_noroi", skip_noroi);
	pSave("val_mode", val_mode);
	pSave("fallback_um", fallback_um);
	pSave("save_qc", save_qc);
	pSave("save_masks", save_masks);
	pSave("nuc_min_um2", nuc_min_um2);
	pSave("nuc_big_um2", nuc_big_um2);
	pSave("nuc_smooth_um", nuc_smooth_um);
	pSave("nuc_bg_um", nuc_bg_um);
	pSave("nuc_method", nuc_method);
	pSave("nuc_mult", nuc_mult);
	pSave("nuc_split", nuc_split);
	pSave("mic_smooth_um", mic_smooth_um);
	pSave("mic_bg_um", mic_bg_um);
	pSave("mic_method", mic_method);
	pSave("mic_mult", mic_mult);
	pSave("close_um", close_um);
	pSave("hole_um2", hole_um2);
	pSave("open_um", open_um);
	pSave("touch_um", touch_um);
	pSave("min_overlap", min_overlap);
	pSave("iba_k", iba_k);
	pSave("one_per_soma", one_per_soma);
	pSave("match_um", match_um);
}

// ----------------------------- dialogs ---------------------------------------
function showDialogs() {
	modeItems = newArray("Single image (the image open now)", "Batch (every .tif in a folder)");
	roiItems = newArray("Whole image (no ROI)", "ROIs saved in the image (selection or overlay)", "ROI .zip file next to the image", "Draw ROIs now (single image only)");
	valItems = newArray("None", "Use existing marks (points in image/ROI file, or NAME_marks.csv)", "Mark cells now (single image only)");
	Dialog.create("Count microglia from Iba1 and DAPI");
	Dialog.addMessage("A nucleus counts as a microglia when it sits inside or touches an Iba1 cell body.\nZ-stacks are max projected. Sizes are in um and use the image pixel size.");
	Dialog.addChoice("Mode:", modeItems, modeItems[run_batch]);
	Dialog.addNumber("Microglia (Iba1) channel:", mic_ch, 0, 3, "");
	Dialog.addNumber("Nuclear (DAPI) channel:", nuc_ch, 0, 3, "");
	Dialog.addCheckbox("Channels are slices of a plain stack (not a hyperstack)", ch_as_slices);
	Dialog.addChoice("Regions:", roiItems, roiItems[roi_src]);
	Dialog.addCheckbox("Skip images without ROIs (otherwise count the whole image)", skip_noroi);
	Dialog.addChoice("Validation with hand-marked cells:", valItems, valItems[val_mode]);
	Dialog.addNumber("Pixel size if the image has none (0 = ask):", fallback_um, 4, 8, "um/px");
	Dialog.addCheckbox("Save QC images (PNG)", save_qc);
	Dialog.addCheckbox("Save nucleus and soma masks (TIF)", save_masks);
	Dialog.addCheckbox("Show advanced parameters next", show_adv);
	Dialog.addCheckbox("Verbose log (for debugging)", verbose);
	Dialog.show();
	run_batch = idxOf(modeItems, Dialog.getChoice());
	mic_ch = round(Dialog.getNumber());
	nuc_ch = round(Dialog.getNumber());
	ch_as_slices = Dialog.getCheckbox();
	roi_src = idxOf(roiItems, Dialog.getChoice());
	skip_noroi = Dialog.getCheckbox();
	val_mode = idxOf(valItems, Dialog.getChoice());
	fallback_um = Dialog.getNumber();
	save_qc = Dialog.getCheckbox();
	save_masks = Dialog.getCheckbox();
	show_adv = Dialog.getCheckbox();
	verbose = Dialog.getCheckbox();
	if (mic_ch < 1 || nuc_ch < 1 || mic_ch == nuc_ch) exit("Choose two different channel numbers (1 or higher).");

	if (show_adv) {
		methods = newArray("Li", "Otsu", "Triangle", "Huang", "Yen", "Mean", "Default", "IsoData", "Moments", "MaxEntropy", "RenyiEntropy");
		Dialog.create("Advanced parameters (um, um2)");
		Dialog.addMessage("NUCLEI (DAPI)");
		Dialog.addNumber("Smoothing sigma:", nuc_smooth_um, 2, 6, "um");
		Dialog.addNumber("Background rolling ball radius (0 = off):", nuc_bg_um, 1, 6, "um");
		Dialog.addChoice("Threshold method:", methods, nuc_method);
		Dialog.addNumber("Threshold multiplier (above 1 = stricter):", nuc_mult, 2, 6, "");
		Dialog.addCheckbox("Split touching nuclei (watershed)", nuc_split);
		Dialog.addNumber("Smallest nucleus kept:", nuc_min_um2, 1, 6, "um2");
		Dialog.addNumber("Flag nuclei larger than:", nuc_big_um2, 1, 6, "um2");
		Dialog.addMessage("IBA1 CELL BODY (SOMA) MASK");
		Dialog.addNumber("Smoothing sigma:", mic_smooth_um, 2, 6, "um");
		Dialog.addNumber("Background rolling ball radius (0 = off):", mic_bg_um, 1, 6, "um");
		Dialog.addChoice("Threshold method:", methods, mic_method);
		Dialog.addNumber("Threshold multiplier (above 1 = stricter):", mic_mult, 2, 6, "");
		Dialog.addNumber("Close gaps up to radius:", close_um, 2, 6, "um");
		Dialog.addNumber("Fill holes up to:", hole_um2, 1, 6, "um2");
		Dialog.addNumber("Remove processes thinner than 2 x:", open_um, 2, 6, "um");
		Dialog.addNumber("Dilate soma mask (touching):", touch_um, 2, 6, "um");
		Dialog.addMessage("DECISION AND VALIDATION");
		Dialog.addNumber("Min fraction of nucleus inside soma mask:", min_overlap, 2, 6, "");
		Dialog.addNumber("Min Iba1 over the nucleus (x Iba1 threshold):", iba_k, 2, 6, "");
		Dialog.addCheckbox("Count only one nucleus per soma mask (the one with most Iba1)", one_per_soma);
		Dialog.addNumber("Mark matching distance:", match_um, 1, 6, "um");
		Dialog.show();
		nuc_smooth_um = Dialog.getNumber();
		nuc_bg_um = Dialog.getNumber();
		nuc_method = Dialog.getChoice();
		nuc_mult = Dialog.getNumber();
		nuc_split = Dialog.getCheckbox();
		nuc_min_um2 = Dialog.getNumber();
		nuc_big_um2 = Dialog.getNumber();
		mic_smooth_um = Dialog.getNumber();
		mic_bg_um = Dialog.getNumber();
		mic_method = Dialog.getChoice();
		mic_mult = Dialog.getNumber();
		close_um = Dialog.getNumber();
		hole_um2 = Dialog.getNumber();
		open_um = Dialog.getNumber();
		touch_um = Dialog.getNumber();
		min_overlap = Dialog.getNumber();
		iba_k = Dialog.getNumber();
		one_per_soma = Dialog.getCheckbox();
		match_um = Dialog.getNumber();
	}
	return true;
}

function writeSettings() {
	s = "CountMicroglia v1 settings, " + getTime() + "\n";
	s = s + "mic_ch=" + mic_ch + " nuc_ch=" + nuc_ch + " roi_src=" + roi_src + " skip_noroi=" + skip_noroi + " val_mode=" + val_mode + "\n";
	s = s + "nuc: smooth_um=" + nuc_smooth_um + " bg_um=" + nuc_bg_um + " method=" + nuc_method + " mult=" + nuc_mult + " split=" + nuc_split + " min_um2=" + nuc_min_um2 + " big_um2=" + nuc_big_um2 + "\n";
	s = s + "mic: smooth_um=" + mic_smooth_um + " bg_um=" + mic_bg_um + " method=" + mic_method + " mult=" + mic_mult + " close_um=" + close_um + " hole_um2=" + hole_um2 + " open_um=" + open_um + " touch_um=" + touch_um + "\n";
	s = s + "min_overlap=" + min_overlap + " iba_k=" + iba_k + " one_per_soma=" + one_per_soma + " match_um=" + match_um + "\n";
	File.saveString(s, out_dir + "CountMicroglia_Settings.txt");
}
