//// MicrogliaMorphology Program 2.3 (batch macro)
//// Created by Jenn Kim on September 18, 2022. Program 2.1 updated January 21, 2026.
//// Program 2.2: segmentation options from the TestImageSettingsPicker, splitting of touching cells, minimum (and optional
//// maximum) cell area in um^2, and the option to start from any step.
//// Program 2.3 adds, from the preprocessing benchmark: (1) optional background removal (rolling ball, sliding paraboloid,
//// Gaussian divide or white top-hat, size in um) before the other preprocessing, (2) hysteresis thresholding (a local
//// low threshold, keeping only particles that also contain a pixel of a strict global high threshold) and (3) an optional
//// soma-seed requirement in step 2 (particles with no soma seed are removed as non-cell objects).
//// Background removal applies to the global, local and hysteresis approaches, not to Tubeness.
//// Program 2.3 also takes its settings straight from the TestImageSettingsPicker (AllOptions version): choose one of the Picker's options and a splitting
//// variant from the lists, or paste the Option name from Top20_Options.csv / AllOptions_Ranked.csv (for example C0U1D1_RB25_local_Mean_r100_splitSoma_seedReq).
//// The name sets preprocessing, background removal, threshold or Tubeness, splitting and the seed requirement. Or set every option yourself as before.
////
//// BEFORE YOU USE THIS MACRO: run the TestImageSettingsPicker (AllOptions version) on a test image from your experiment and mark the cells.
//// Its Top20_Options.csv and AllOptions_Ranked.csv tell you which option works best for your images. Choose that option here.
////
//// THE THREE STEPS (you choose the first step to run and the last step to run)
////   Step 1  Preprocess and threshold the original images -> ThresholdedImages/<image>_thresholded.tif
////           preprocessing: contrast stretch, unsharp mask, despeckle (each on or off)
////           segmentation: auto threshold (global), auto local threshold, or Tubeness ridge filter
////           post-processing: Despeckle, Close-, Remove Outliers (Program 2 standard)
////   Step 2  Split touching cells in the thresholded masks -> SplitImages/<image>_thresholded.tif
////           soma-seeded watershed (needs the original images for the soma seeds)
////   Step 3  Measure single cells (area filters, hull, skeleton) -> MeasurementResults/<image>.csv
////
//// AREA FILTERS are in um^2 and need calibrated images. The macro reports the pixel size it reads and asks if it is correct.
//// The lower filter removes small non-cell particles. The upper filter is no longer needed: touching cells are
//// separated by step 2. Use an upper filter only to remove large debris.
////
//// Names of the options match the TestImageSettingsPicker (for example C0U1D1_auto_Huang): C = contrast stretch,
//// U = unsharp mask, D = despeckle, 1 = on, 0 = off.

// ---------------------------------------------------------------------------
// GLOBALS
// ---------------------------------------------------------------------------
var benchPixel = 0.3447;
var sigma_scale = 1;
var radius_scale = 1;
var run_start = 0;
var channel = 1;
var had_overlay = false;

// preprocessing and thresholding
var us_radius = 3;
var us_weight = 0.6;
var pp_code = "C0U1D1";
var bg_code = "";
var hi_method = "Otsu";
var seed_req = false;
var seed_removed = "NA";
var thr_type = "auto";
var thr_method = "Huang";
var thr_radius = 100;
var post_on = true;
var soma_sd = 2;
var tube_cutoff = 20;
var tube_cut_list = "20";
var tube_cuts = newArray(1);
var tv_idx = 0;
var tv_name = newArray("TubeOrig", "Tube3", "Tube3Post", "Tube3R100");
var tv_sigmas = newArray("0.9,0.5,0.1,0.05,0.005", "0.9,0.5,0.1", "0.9,0.5,0.1", "0.9,0.5,0.1");
var tv_radius = newArray(200, 200, 200, 100);
var tv_post = newArray(0, 0, 1, 0);
var reuse_tube = false;
var tbc_keys = newArray(0);
var tbc_tub = newArray(0);
var tbc_gate = newArray(0);
var tbc_med = newArray(0);
var tbc_mad = newArray(0);
var tm_soma = "NA";
var tm_tub = "NA";
var tm_gate = "NA";
var tm_thr = "NA";
var tm_close = "NA";
var tm_sigma_str = "NA";
var eff_cut_str = "NA";
var tm_cached = false;
var g_tk = 0;
var g_tg = 0;
var g_med8 = 0;
var g_mad8 = 0;
var g_cut_used = 0;
var morpho_ok = false;
var warned_close = false;
var fg_ratio = "NA";
var fixed_binary = false;

// splitting
var split_mode = 0;
var px_checked = false;
var px_override = 0;
var split_sigma_um = 3;
var split_sigma_px = 12;
var split_prom = 8;
var split_min_px = 1;
var split_multi = "NA";
var pm_pre = "NA";

// area filters and measurement
var area_min = 100;
var area_max = 0;
var roichoice = true;

var valid_auto = newArray("Default", "Huang", "Huang2", "Intermodes", "IsoData", "IJ_IsoData", "Li", "MaxEntropy", "Mean", "MinError(I)", "Minimum", "Moments", "Otsu", "Percentile", "RenyiEntropy", "Shanbhag", "Triangle", "Yen");
var valid_local = newArray("Bernsen", "Contrast", "Mean", "Median", "MidGrey", "Niblack", "Otsu", "Phansalkar", "Sauvola");

// output tables of this macro
var produced = newArray(0);

// ---------------------------------------------------------------------------
// FUNCTIONS COPIED FROM THE TestImageSettingsPicker (same code, so the batch result matches the montage)
// ---------------------------------------------------------------------------

function keep_channel(ch) {
	getDimensions(width, height, channels, slices, frames);
	for (i = channels; i > 0; i--) {
		Stack.setChannel(i);
		if (i != ch) {
			run("Delete Slice", "delete=channel");
		}
	}
}

function fix_lut() {
	if (is("Inverting LUT")) {
		run("Invert LUT");
	}
}

function stamp(msg) {
	getDateAndTime(yr, mo, dw, dm, hr, mi, sc, ms);
	print("[" + IJ.pad(hr, 2) + ":" + IJ.pad(mi, 2) + ":" + IJ.pad(sc, 2) + " +" + d2s((getTime() - run_start) / 1000, 0) + "s] " + msg);
}

function sec(ms) {
	return d2s(ms / 1000, 1) + " s";
}

function split_list(str) {
	clean = replace(str, " ", "");
	if (lengthOf(clean) == 0) {
		return newArray(0);
	}
	return split(clean, ",");
}

function canon_method(name, valid, plugin) {
	for (q = 0; q < valid.length; q++) {
		if (toLowerCase(valid[q]) == toLowerCase(name)) {
			return valid[q];
		}
	}
	exit("Unknown " + plugin + " method: " + name + "\nValid names: " + String.join(valid, ", "));
}

function normalize_binary() {
	fix_lut();
	run("Select None");
	fg_ratio = "NA";
	getRawStatistics(npx, mmask);
	if (mmask == 0 || mmask == 255) {
		return;
	}
	imageCalculator("AND create", "base_img", "work");
	rt = getTitle();
	getRawStatistics(npx2, mand);
	close(rt);
	selectImage("base_img");
	getRawStatistics(npx3, mall);
	selectImage("work");
	fgpx = mmask / 255 * npx;
	sum_in = mand * npx2;
	mean_in = sum_in / fgpx;
	if (mean_in < mall) {
		run("Invert");
		print("      note: mask polarity flipped (foreground was darker than the image average)");
		mean_in = (mall * npx3 - sum_in) / (npx - fgpx);
	}
	if (mall > 0) {
		fg_ratio = mean_in / mall;
	}
}

function ensure_binary() {
	run("Select None");
	fix_lut();
	fixed_binary = false;
	getDimensions(bw, bh, bc, bs, bf);
	getHistogram(hvals, hcounts, 256);
	if (hcounts[0] + hcounts[255] < bw * bh) {
		print("      note: result was not strictly 0/255; binarised at 128");
		setThreshold(128, 255);
		run("Convert to Mask");
		fix_lut();
		fixed_binary = true;
	}
}

function numtag(x) {
	return replace("" + x, "\\.", "p");
}

// the active image is the preprocessed 8-bit copy; it is still the active image, with the same title, on return
function apply_background(bg) {
	t = getTitle();
	kind = substring(bg, 0, 2);
	val = parseFloat(replace(substring(bg, 2), "p", "."));
	px = val * sigma_scale;
	run("Select None");
	if (kind == "RB") {
		run("Subtract Background...", "rolling=" + d2s(px, 2));
	} else if (kind == "SP") {
		run("Subtract Background...", "rolling=" + d2s(px, 2) + " sliding");
	} else if (kind == "GD") {
		run("Duplicate...", "title=bg_est");
		run("Gaussian Blur...", "sigma=" + d2s(px, 2));
		run("32-bit");
		run("Add...", "value=1");
		getRawStatistics(nn, bmean);
		selectImage(t);
		run("32-bit");
		imageCalculator("Divide", t, "bg_est");
		selectImage(t);
		run("Multiply...", "value=" + bmean);
		setMinAndMax(0, 255);
		run("8-bit");
		close("bg_est");
	} else if (kind == "TH") {
		run("Morphological Filters", "operation=[White Top Hat] element=Disk radius=" + d2s(maxOf(1, round(px)), 0));
		res = getTitle();
		if (res != t) {
			selectImage(t);
			close();
			selectImage(res);
			rename(t);
		}
	} else {
		exit("Unknown background removal code: " + bg);
	}
	selectImage(t);
}

// keep only the particles of "work" that contain a marker pixel (used by hysteresis and the soma-seed requirement)
// mk = title of a 0/255 image (255 = marker). Returns the number of particles removed.
function keep_with_marker(mk) {
	selectImage("work");
	run("Select None");
	sw = getWidth();
	sh = getHeight();
	setThreshold(255, 255);
	roiManager("reset");
	run("Set Measurements...", "integrated redirect=" + mk + " decimal=3");
	run("Analyze Particles...", "size=0-Infinity pixel display clear add");
	resetThreshold();
	np = roiManager("count");
	newImage("kw_new", "8-bit black", sw, sh, 1);
	setForegroundColor(255, 255, 255);
	nk = 0;
	for (pi = 0; pi < np; pi++) {
		if (getResult("RawIntDen", pi) > 0) {
			roiManager("select", pi);
			run("Fill", "slice");
			nk++;
		}
	}
	roiManager("deselect");
	roiManager("reset");
	run("Clear Results");
	run("Set Measurements...", "area shape redirect=None decimal=4");
	// the particle outlines fill any holes inside the cells: AND with the old mask puts the holes back
	imageCalculator("AND", "kw_new", "work");
	selectImage("work");
	close();
	selectImage("kw_new");
	rename("work");
	fix_lut();
	return np - nk;
}

// binarise-check and orient image t (white objects) with the routines that work on "work"
function polarize(t) {
	selectImage("work");
	rename("hy_hold");
	selectImage(t);
	rename("work");
	ensure_binary();
	normalize_binary();
	selectImage("work");
	rename(t);
	selectImage("hy_hold");
	rename("work");
}

// lowM: local method (radius > 0) or global method (radius = 0), the permissive mask; highM: global method, the strict mask
function apply_hysteresis(lowM, highM, radius) {
	selectImage("work");
	run("Select None");
	run("Duplicate...", "title=hy_hi");
	run("Auto Threshold", "method=" + highM + " ignore_black white");
	polarize("hy_hi");
	selectImage("work");
	if (radius > 0) {
		run("Auto Local Threshold", "method=" + lowM + " radius=" + radius + " parameter_1=0 parameter_2=0 white");
	} else {
		run("Auto Threshold", "method=" + lowM + " ignore_black white");
	}
	ensure_binary();
	normalize_binary();
	nrem = keep_with_marker("hy_hi");
	close("hy_hi");
	print("      hysteresis: " + nrem + " low-threshold particles had no " + highM + " pixel and were removed");
}

// remove particles that contain no soma seed (same seeds as the soma split); returns the number removed
function require_seed(sig_px, prom) {
	selectImage("base_img");
	run("Select None");
	run("Duplicate...", "title=sd_seed");
	run("Gaussian Blur...", "sigma=" + sig_px);
	run("Find Maxima...", "prominence=" + prom + " output=[Single Points]");
	rename("sd_pts2");
	fix_lut();
	getRawStatistics(npx, mpts);
	if (mpts > 127.5) {
		run("Invert");
	}
	close("sd_seed");
	removed = keep_with_marker("sd_pts2");
	close("sd_pts2");
	return removed;
}

function apply_pp(pp) {
	run("Select None");
	if (bg_code != "") {
		apply_background(bg_code);
		run("Select None");
	}
	if (substring(pp, 1, 2) == "1") {
		run("Enhance Contrast", "saturated=0.35 normalize");
	}
	if (substring(pp, 3, 4) == "1") {
		run("Unsharp Mask...", "radius=" + us_radius + " mask=" + us_weight);
	}
	if (substring(pp, 5, 6) == "1") {
		run("Despeckle");
	}
}

function apply_threshold(type, method, radius) {
	if (type == "auto") {
		run("Auto Threshold", "method=" + method + " ignore_black white");
	}
	if (type == "local") {
		run("Auto Local Threshold", "method=" + method + " radius=" + maxOf(1, round(radius * radius_scale)) + " parameter_1=0 parameter_2=0 white");
	}
	if (type == "hyst") {
		hi = indexOf(method, "-hi");
		apply_hysteresis(substring(method, 0, hi), substring(method, hi + 3), maxOf(1, round(radius * radius_scale)));
	}
}

function postprocess() {
	run("Despeckle");
	run("Close-");
	run("Remove Outliers...", "radius=2 threshold=50 which=Bright");
}

function close_disk(r) {
	t = getTitle();
	if (morpho_ok) {
		run("Morphological Filters", "operation=Closing element=Disk radius=" + r);
		res = t + "-Closing";
		selectImage(t);
		close();
		selectImage(res);
		rename(t);
	} else {
		if (!warned_close) {
			print("MorphoLibJ not found: using Close- in place of disk closing in the Tubeness arms.");
			warned_close = true;
		}
		run("Close-");
	}
}

function compute_response(base, sig, use_cal) {
	ts = getTime();
	selectImage(base);
	run("Tubeness", "sigma=" + sig + use_cal);
	selectImage("tubeness of " + base);
	// robust noise level of the ridge response, converted to the 0-255 units that the 8-bit conversion will use
	getMinAndMax(dmin, dmax);
	getStatistics(ar0, mn0, lo0, hi0);
	g_med8 = 0;
	g_mad8 = 0;
	if (hi0 > lo0 && dmax > dmin) {
		nb = 4096;
		getHistogram(hv, hc, nb, lo0, hi0);
		bw = (hi0 - lo0) / nb;
		tot = 0;
		for (q = 1; q < nb; q++) {
			tot = tot + hc[q];
		}
		cum = 0;
		mb = 1;
		for (q = 1; q < nb; q++) {
			cum = cum + hc[q];
			if (cum >= tot / 2) {
				mb = q;
				q = nb;
			}
		}
		dc = newArray(nb);
		for (q = 1; q < nb; q++) {
			dv = abs(q - mb);
			dc[dv] = dc[dv] + hc[q];
		}
		cum = 0;
		db = 0;
		for (q = 0; q < nb; q++) {
			cum = cum + dc[q];
			if (cum >= tot / 2) {
				db = q;
				q = nb;
			}
		}
		med32 = lo0 + (mb + 0.5) * bw;
		mad32 = (db + 0.5) * bw;
		sc8 = 255 / (dmax - dmin);
		g_med8 = (med32 - dmin) * sc8;
		g_mad8 = mad32 * sc8;
	}
	run("8-bit");
	rename("tb_feat");
	g_tk = getTime() - ts;
}

function gate_response() {
	t1 = getTime();
	selectImage("tb_feat");
	run("Duplicate...", "title=tb_mult");
	cutv = tube_cutoff;
	if (tube_cutoff < 0) {
		cutv = g_med8 + (-tube_cutoff) * 1.4826 * g_mad8;
	}
	cutv = minOf(maxOf(cutv, 1), 254);
	g_cut_used = cutv;
	setThreshold(cutv, 255);
	run("Convert to Mask");
	run("Divide...", "value=255");
	imageCalculator("Multiply create", "tb_feat", "tb_mult");
	rt = getTitle();
	close("tb_feat");
	close("tb_mult");
	selectImage(rt);
	rename("tb_feat");
	g_tg = getTime() - t1;
}

function tubeness_segment(v) {
	base = getTitle();
	getPixelSize(unit, pw, ph);
	use_cal = "";
	if (unit != "pixels" && unit != "pixel" && unit != "") {
		use_cal = " use";
	}
	sigmas = split(replace(tv_sigmas[v], " ", ""), ",");

	// soma / bright layer: mean + N*SD of the non-zero pixels
	t = getTime();
	selectImage(base);
	run("Select None");
	run("Duplicate...", "title=tb_soma");
	run("Set Measurements...", "mean standard limit redirect=None decimal=9");
	setThreshold(1, 255);
	run("Measure");
	mval = getResult("Mean", nResults - 1);
	sdval = getResult("StdDev", nResults - 1);
	run("Clear Results");
	resetThreshold();
	setThreshold(minOf(mval + soma_sd * sdval, 254), 255);
	run("Convert to Mask");
	tm_soma = getTime() - t;
	stamp("      soma layer: " + sec(tm_soma));

	tm_tub = 0;
	tm_gate = 0;
	tm_thr = 0;
	tm_close = 0;
	tm_sigma_str = "";
	eff_cut_str = "";
	for (k = 0; k < sigmas.length; k++) {
		ts = getTime();
		key = sigmas[k];
		ci = -1;
		for (q = 0; q < tbc_keys.length; q++) {
			if (tbc_keys[q] == key) {
				ci = q;
			}
		}
		hit = "";
		if (reuse_tube && ci >= 0 && isOpen("tbc_" + key)) {
			selectImage("tbc_" + key);
			run("Duplicate...", "title=tb_feat");
			tk = tbc_tub[ci];
			g_med8 = tbc_med[ci];
			g_mad8 = tbc_mad[ci];
			tm_cached = true;
			hit = " (reused response; filter time is the original cost)";
		} else {
			compute_response(base, key, use_cal);
			tk = g_tk;
			if (reuse_tube) {
				selectImage("tb_feat");
				run("Duplicate...", "title=tbc_" + key);
				tbc_keys = Array.concat(tbc_keys, key);
				tbc_tub = Array.concat(tbc_tub, tk);
				tbc_gate = Array.concat(tbc_gate, 0);
				tbc_med = Array.concat(tbc_med, g_med8);
				tbc_mad = Array.concat(tbc_mad, g_mad8);
				selectImage("tb_feat");
			}
		}
		selectImage("tb_feat");
		gate_response();
		tg = g_tg;
		eff_cut_str = eff_cut_str + key + ":" + d2s(g_cut_used, 1) + " ";
		tm_tub = tm_tub + tk;
		tm_gate = tm_gate + tg;

		t1 = getTime();
		run("Auto Local Threshold", "method=Phansalkar radius=" + maxOf(1, round(tv_radius[v] * radius_scale)) + " parameter_1=0 parameter_2=0 white");
		fix_lut();
		tt = getTime() - t1;
		tm_thr = tm_thr + tt;

		t1 = getTime();
		close_disk(1);
		close_disk(1);
		tc = getTime() - t1;
		tm_close = tm_close + tc;

		imageCalculator("Max", "tb_soma", "tb_feat");
		close("tb_feat");
		tm_sigma_str = tm_sigma_str + sigmas[k] + ":" + round(getTime() - ts) + " ";
		stamp("      sigma " + sigmas[k] + ": tubeness " + sec(tk) + " | gate " + sec(tg) + " (cutoff " + d2s(g_cut_used, 1) + ", noise median " + d2s(g_med8, 1) + ", MAD " + d2s(g_mad8, 2) + ") | threshold " + sec(tt) + " | closing " + sec(tc) + hit);
	}

	t1 = getTime();
	selectImage("tb_soma");
	close_disk(1.5);
	tc = getTime() - t1;
	tm_close = tm_close + tc;
	stamp("      final closing: " + sec(tc));
	selectImage(base);
	close();
	selectImage("tb_soma");
	rename(base);
}

function count_particles() {
	run("Select None");
	setThreshold(255, 255);
	run("Analyze Particles...", "size=0-Infinity pixel summarize");
	resetThreshold();
	pm_pre = Table.get("Count", Table.size("Summary") - 1, "Summary");
	close("Summary");
}

function split_cells(mode) {
	selectImage("work");
	run("Select None");
	sw = getWidth();
	sh = getHeight();
	minpx = maxOf(split_min_px, 1);
	split_multi = "NA";
	if (mode == 1) {
		// seeds: maxima of the blurred raw image (one per soma); segmentation: watershed basins between them
		selectImage("base_img");
		run("Select None");
		run("Duplicate...", "title=sd_seed");
		run("Gaussian Blur...", "sigma=" + split_sigma_px);
		run("Find Maxima...", "prominence=" + split_prom + " output=[Single Points]");
		rename("sd_pts");
		fix_lut();
		getRawStatistics(npx, mpts);
		if (mpts > 127.5) {
			run("Invert");
		}
		selectImage("sd_seed");
		run("Find Maxima...", "prominence=" + split_prom + " output=[Segmented Particles]");
		rename("sd_seg");
		fix_lut();
		getRawStatistics(npx, mseg);
		if (mseg < 127.5) {
			run("Invert");
		}
		close("sd_seed");

		// count the seeds in every particle at or above the minimum area
		selectImage("work");
		setThreshold(255, 255);
		roiManager("reset");
		run("Set Measurements...", "integrated redirect=sd_pts decimal=3");
		run("Analyze Particles...", "size=" + minpx + "-Infinity pixel display clear add");
		resetThreshold();
		np = roiManager("count");
		newImage("sp_multi", "8-bit black", sw, sh, 1);
		setForegroundColor(255, 255, 255);
		nmulti = 0;
		for (pi = 0; pi < np; pi++) {
			seeds = getResult("RawIntDen", pi) / 255;
			if (seeds >= 1.5) {
				roiManager("select", pi);
				run("Fill", "slice");
				nmulti++;
			}
		}
		roiManager("deselect");
		roiManager("reset");
		run("Clear Results");
		run("Set Measurements...", "area shape redirect=None decimal=4");
		split_multi = nmulti;
		// cut only inside particles that hold two or more seeds
		selectImage("sp_multi");
		run("Select None");
		run("Invert");
		imageCalculator("OR", "sp_multi", "sd_seg");
		imageCalculator("AND", "work", "sp_multi");
		close("sp_multi");
		close("sd_seg");
		close("sd_pts");
	}
	selectImage("work");
	fix_lut();
}

function parse_cut_list() {
	cg = split_list(tube_cut_list);
	if (cg.length == 0) {
		cg = newArray("10");
	}
	tube_cuts = newArray(cg.length);
	for (q = 0; q < cg.length; q++) {
		tk0 = String.trim(cg[q]);
		if (startsWith(tk0, "k") || startsWith(tk0, "K")) {
			tube_cuts[q] = -maxOf(parseFloat(substring(tk0, 1)), 0.1);
		} else {
			tube_cuts[q] = parseFloat(tk0);
		}
	}
}

// ---------------------------------------------------------------------------
// Settings from a TestImageSettingsPicker option name, for example
//   C0U1D1_RB25_local_Mean_r100_splitSoma_seedReq     C0U1D1_hyst_Niblack-hiOtsu_r100_splitSoma     TubeOrig_c15_splitSoma_seedReq
//   C0U1D1_local_Niblack_r100_splitSoma_s2.0_p12      C1U0D0_auto_Li_splitSoma_seedReq
// Sets pp_code, bg_code, thr_type, thr_method, thr_radius, hi_method, tv_idx, tube_cut_list, split_mode, split_sigma_um, split_prom, seed_req.
// Returns true when the name was understood.
// ---------------------------------------------------------------------------
function parse_picker_name(nm) {
	nm = String.trim(nm);
	seed_req = false;
	if (endsWith(nm, "_seedReq")) {
		seed_req = true;
		nm = substring(nm, 0, lengthOf(nm) - 8);
	}
	split_mode = 0;
	split_sigma_um = 3;
	split_prom = 8;
	k = indexOf(nm, "_splitSoma");
	if (k >= 0) {
		split_mode = 1;
		tail = substring(nm, k + 10);
		nm = substring(nm, 0, k);
		if (startsWith(tail, "_s")) {
			j = indexOf(tail, "_p");
			if (j > 2) {
				split_sigma_um = parseFloat(substring(tail, 2, j));
				split_prom = parseFloat(substring(tail, j + 2));
			}
		}
	}
	parts = split(nm, "_");
	np = parts.length;
	if (np < 2) {
		return false;
	}
	if (startsWith(parts[0], "Tube")) {
		found = -1;
		for (q = 0; q < tv_name.length; q++) {
			if (tv_name[q] == parts[0]) {
				found = q;
			}
		}
		if (found < 0) {
			return false;
		}
		tag = parts[1];
		if (startsWith(tag, "c")) {
			tag = substring(tag, 1);
		}
		tv_idx = found;
		tube_cut_list = tag;
		parse_cut_list();
		thr_type = "tubeness";
		thr_method = tv_name[found];
		bg_code = "";
		return true;
	}
	pp_code = parts[0];
	if (lengthOf(pp_code) != 6) {
		return false;
	}
	bg_code = "";
	i = 1;
	if (matches(parts[1], "(RB|SP|GD|TH)[0-9p]+")) {
		bg_code = parts[1];
		i = 2;
	}
	if (i + 1 >= np) {
		return false;
	}
	t = parts[i];
	if (t == "auto") {
		thr_type = "auto";
		thr_method = parts[i + 1];
		return true;
	}
	if (i + 2 >= np) {
		return false;
	}
	rtag = parts[i + 2];
	if (!startsWith(rtag, "r")) {
		return false;
	}
	thr_radius = parseFloat(substring(rtag, 1));
	if (t == "local") {
		thr_type = "local";
		thr_method = parts[i + 1];
		return true;
	}
	if (t == "hyst") {
		thr_type = "hyst";
		thr_method = parts[i + 1];
		h = indexOf(thr_method, "-hi");
		if (h < 1) {
			return false;
		}
		hi_method = substring(thr_method, h + 3);
		return true;
	}
	return false;
}

function list_images(dir) {
	all = getFileList(dir);
	all = Array.sort(all);
	keep = newArray(0);
	for (i = 0; i < all.length; i++) {
		lc = toLowerCase(all[i]);
		if (!endsWith(lc, "/") && !startsWith(lc, ".")) {
			if (endsWith(lc, ".tif") || endsWith(lc, ".tiff") || endsWith(lc, ".png") || endsWith(lc, ".jpg") || endsWith(lc, ".jpeg")) {
				keep = Array.concat(keep, all[i]);
			}
		}
	}
	return keep;
}


// ---------------------------------------------------------------------------
// FUNCTIONS FROM PROGRAM 2.1: single cell ROIs and measurements (step 3)
// New in 2.2: area filters in um^2; the upper filter is skipped when it is 0.
// ---------------------------------------------------------------------------

function cellROI(input, output, filename, min, max, do_channel_quantification, original_file_path, quantification_channel, image_number, total_image_number){
		close("Results");
		close("ROI Manager");
		//print(input + filename);
    	open(input + filename);
    	ensure_scale(filename);
    	
    	mainTitle=getTitle();
		dirCropOutput=output;
		
		//spaces in the imagename break the skeleton analysis
		mainTitle_safe = mainTitle.replace(" ", "_");
		rename(mainTitle_safe);
		
		//if you want to ignore the Regions
		if (!roichoice) {
			Overlay.remove;
			run("Select None");
		}
		
		//if there is not yet an overlay, make one
		if (Overlay.size < 1) {
			Overlay.remove;
			has_selection = selectionType();
			//either of the current selection or the entire brain if there is no current selection
			if (has_selection == -1) {
				run("Select All");
				setSelectionName("full_brain");
				Overlay.addSelection;
				run("Select None");
			} else {
				Overlay.addSelection;
				run("Select None");
			}
		}
		//retrieve how many regions we have to go through
		region_number = Overlay.size;
		
		//print output if something went wrong
		response = "";
		Table.create("All_results");
		

		if(do_channel_quantification) {
			open(original_file_path);
			getDimensions(width, height, channels, slices, frames);
		
			for (i = channels; i > 0; i--) {
				Stack.setChannel(i);
				if (i != quantification_channel) {
					run("Delete Slice", "delete=channel");
				}
			}
			original_image = getTitle();
			run("8-bit");
		}
		
		for (current_region = 0; current_region < region_number; current_region++) {
			
			selectWindow(mainTitle_safe);
			run("To ROI Manager");
			//Overlay.remove;//do not have to do this if the overlay just stays like this the entire time
			
			roiManager("select", current_region);
			region = Roi.getName;
			//print("Working on region " + region + ". " + (current_region + 1) + " / " + region_number);
			//this only duplicates the specific region
			run("Duplicate...", "title=region_image ignore");
			
setBackgroundColor(0, 0, 0);
			
			//test if the region actually still exists, in case the region lay outside the image
			if (selectionType() != -1) {
				run("Clear Outside");
	
				selectWindow(mainTitle_safe);
				run("From ROI Manager");
				roiManager("reset");
				run("Select None");
				
				selectWindow("region_image");
			    run("Select None");
				run("Set Measurements...", "area display redirect=None decimal=3");
				
				run("Analyze Particles...", "pixel add");
				roiManager("Measure");	
				
				if (nResults > 0) {
					selectWindow("Results");
					area = Table.getColumn("Area");
					label = Table.getColumn("Label");
					close("Results");
					if (do_channel_quantification) {
						run("Set Measurements...", "area mean min perimeter fit shape feret's integrated stack display redirect=None decimal=9");
					} else {
						run("Set Measurements...", "area perimeter fit shape feret's stack display redirect=None decimal=9");
					}
	
	
					for (i = 0; i < area.length; i++) {
				
						keep_cell = (area[i] >= min);
						if (max > 0) {
							if (area[i] > max) {
								keep_cell = false;
							}
						}
						if (keep_cell) {
							print("[Progress]", "\\Update:Analyzing image " + (image_number + 1) + "/" + total_image_number + ": " + filename + "\nRegion " + (current_region + 1) + "/" + region_number + ": " + region + "\ncell: " + (i + 1) + "/" + area.length);
							selectWindow("region_image");
							label_temp = label[i];
							label_temp = label_temp.replace(':','_');
							
							if(do_channel_quantification) {
								selectWindow(original_image);
							}
							roiManager("Select", i);
							run("Duplicate...", "title=" + label_temp);
							
							setBackgroundColor(0, 0, 0);
							run("Clear Outside");
			    			
			    			analyze(label_temp, filename, region);
			    			
							//print(filename);
							//print(region + ": " + i + "/" + area.length);
							close(label_temp);
							
						}
					}
				} else {
					
					print("No cells found in " + filename + " " + region);
					response = response + " " + region + ";";
				}
			} else {
				//reset the overlay when the region did not exist after all
				selectWindow(mainTitle_safe);
				run("From ROI Manager");
				roiManager("reset");
				run("Select None");
			}
			//after the check of nResults > 0
			close("region_image");
			close("ROI Manager");
		}
		//after processing all regions
		close(mainTitle_safe);
		selectWindow("All_results");
		
		
if(do_channel_quantification) {				
			close(original_image);
		}
		
		//if no cells were detected still create the table headings
		if (Table.size == 0) {
			selectWindow("All_results");
			Table.set("Label", 0, filename);
			Table.set("Image", 0, filename);
			Table.set("Region", 0, "NA");
			if (do_channel_quantification) {
				headings = newArray("Label", "Area", "Mean", "Min", "Max", "Perim.", "Major", "Minor", "Circ.", "Feret", "IntDen", "RawIntDen", "MinFeret", "Round", "Solidity", "Angle", "Slice", "FeretX", "FeretY", "FeretAngle", "AR");
			} else {
				headings = newArray("Label", "Area", "Perim.", "Major", "Minor", "Circ.", "Feret", "MinFeret", "Round", "Solidity", "Angle", "Slice", "FeretX", "FeretY", "FeretAngle", "AR");
			}
			
			for (i = 0; i < headings.length; i++) {
				Table.set(headings[i], 0, "NA");
			}
			for (i = 0; i < headings.length; i++) {
				Table.set("hull_" + headings[i], 0, "NA");
			}
			Table.set("Hull span ratio", 0, "NA");
			Table.set("Max/min radii from hull", 0, "NA");
			Table.set("Relative variation (CV) hull", 0, "NA");
			Table.set("skeleton_# Branches", 0, "NA");
			Table.set("skeleton_# Junctions", 0, "NA");
			Table.set("skeleton_# End-point voxels", 0, "NA");
			Table.set("skeleton_# Junction voxels", 0, "NA");
			Table.set("skeleton_# Slab voxels", 0, "NA");
			Table.set("skeleton_Average Branch Length", 0, "NA");
			Table.set("skeleton_# Triple points", 0, "NA");
			Table.set("skeleton_# Quadruple points", 0, "NA");
			Table.set("skeleton_Maximum Branch Length", 0, "NA");
			
			
		}
		selectWindow("All_results");
		//deleting unneccessary results
		Table.deleteColumn("Angle");
		Table.deleteColumn("Slice");
		Table.deleteColumn("FeretX");
		Table.deleteColumn("FeretY");
		Table.deleteColumn("FeretAngle");
		Table.deleteColumn("AR");
		Table.deleteColumn("hull_Label");
		if (do_channel_quantification) {
			Table.deleteColumn("hull_Mean");
			Table.deleteColumn("hull_Min");
			Table.deleteColumn("hull_Max");
			Table.deleteColumn("RawIntDen");
			Table.deleteColumn("hull_RawIntDen");
			
		}
		Table.deleteColumn("hull_Angle");
		Table.deleteColumn("hull_Slice");
		Table.deleteColumn("hull_FeretX");
		Table.deleteColumn("hull_FeretY");
		Table.deleteColumn("hull_FeretAngle");
		Table.deleteColumn("hull_AR");
		saveAs("results", output + File.getNameWithoutExtension(input + filename) + ".csv");
		close(File.getNameWithoutExtension(input + filename) + ".csv");
		if (response != "") {
			response = filename + ":" + response; 
		}
		return response;

    }

function analyze(name, image, region) {
	setThreshold(1, 255);
	
	run("To Selection");
	
	run("Measure");
	
	selectWindow("Results");
	cell_headings = String.getResultsHeadings();
	cell_headings = split(cell_headings, "\t");
	cell_headings = Array.deleteValue(cell_headings, " ");
	
	cell_results = newArray(cell_headings.length);
	selectWindow("Results");
	for (i = 0; i < cell_headings.length; i++) {
		cell_results[i] = Table.getString(cell_headings[i], 0);
	}
	
	close("Results");
	selectWindow("All_results");//store cell results in second table
	
	result_row_number = Table.size;
	
	Table.set("Image", result_row_number, image);
	Table.set("Region", result_row_number, region);
	
	
	for (i = 0; i < cell_headings.length; i++) {
		Table.set(cell_headings[i], result_row_number, cell_results[i]);
	}
	
	run("Convex Hull");
	run("Measure"); // this gets results for the hull data one for loop lower
	
	selectWindow("Results");
	hull_headings = String.getResultsHeadings();
	hull_headings = split(hull_headings, "\t");
	hull_headings = Array.deleteValue(hull_headings, " ");
	
	
	major_feret = getValue("Feret");
	minor_feret = getValue("MinFeret");
	span = major_feret / minor_feret;
	long_radii = get_long_radii();
	max_radius = get_max(long_radii);
	short_radii = get_short_radii(long_radii);
	min_radius = get_min(short_radii);
	radius_ratio = max_radius / min_radius;
	Array.getStatistics(Array.concat(long_radii, short_radii), min, max, mean, stdDev);
	coefficient_of_variation = stdDev / mean;
	
	hull_results = newArray(hull_headings.length);
	selectWindow("Results");
	for (i = 0; i < hull_headings.length; i++) {
		hull_results[i] = Table.getString(hull_headings[i], 0);
	}
	
	close("Results");
	selectWindow("All_results");
	for (i = 0; i < hull_headings.length; i++) {
		Table.set("hull_" + hull_headings[i], result_row_number, hull_results[i]);
	}
	
	Table.set("Hull span ratio", result_row_number, span);
	Table.set("Max/min radii from hull", result_row_number, radius_ratio);
	Table.set("Relative variation (CV) hull", result_row_number, coefficient_of_variation);
	
	//now do skeleton stuff
	run("Select None");
	run("Skeletonize (2D/3D)");
	//now that ROIs are obtained, can perform skeleton
	run("Analyze Skeleton (2D/3D)", "prune=none show");
	close("Branch information"); //do not need this (yet), could integrate & 
	close("Tagged skeleton");
	close(name + "-labeled-skeletons");
	
	//get column titles as array
	selectWindow("Results");
	skeleton_headings = String.getResultsHeadings();
	skeleton_headings = split(skeleton_headings, "\t");
	skeleton_headings = Array.deleteValue(skeleton_headings, " ");
	
	//get data associated with these headings
	skeleton_results = newArray(skeleton_headings.length);
	selectWindow("Results");
	for (i = 0; i < skeleton_headings.length; i++) {
		skeleton_results[i] = Table.getString(skeleton_headings[i], 0);
	}
	
	close("Results");
	selectWindow("All_results");
	for (i = 0; i < skeleton_headings.length; i++) {
		Table.set("skeleton_" + skeleton_headings[i], result_row_number, skeleton_results[i]);
	}
	
}

function get_long_radii() {
	center_of_mass_x = getValue("XM");
	center_of_mass_y = getValue("YM");
	
	getSelectionCoordinates(xpoints, ypoints);
	
	//from each node of the ROI get the distance to the center of mass
	all_corner_distances = newArray(xpoints.length);
	for (i = 0; i < all_corner_distances.length; i++) {
		all_corner_distances[i] = sqrt(abs(Math.pow(xpoints[i] - center_of_mass_x, 2) + Math.pow(ypoints[i] - center_of_mass_y, 2)));
	}
	
	return all_corner_distances;
}

function get_short_radii(long_radii) {
	getSelectionCoordinates(xpoints, ypoints);
	//from each edge of the ROI get the smallest distance to the center of mass (height of triangle when edge is the base)
	all_midpoint_distances = newArray(long_radii.length);
	
	//Heron's formula to calc height of triangle: get length of all sides
	//gotta start with the connection between the first and last point outside the loop
	base_length = sqrt(abs(Math.pow(xpoints[0] - xpoints[xpoints.length - 1], 2) + Math.pow(ypoints[0] - ypoints[ypoints.length - 1], 2)));
	//the two distances of the corners to the center of mass were already calculated
	side_a_length = long_radii[0];
	side_b_length = long_radii[long_radii.length - 1];
	
	semiperimeter = (side_a_length + base_length + side_b_length) / 2;
	triangle_area = sqrt(semiperimeter * (semiperimeter - side_a_length) * (semiperimeter - base_length) * (semiperimeter - side_b_length));
	all_midpoint_distances[0] = 2 * triangle_area / base_length;
	
	//now do the same for the rest of the point pairs 
	for (i = 1; i < all_midpoint_distances.length; i++) {
		base_length = sqrt(abs(Math.pow(xpoints[i] - xpoints[i - 1], 2) + Math.pow(ypoints[i] - ypoints[i - 1], 2)));
		side_a_length = long_radii[i];
		side_b_length = long_radii[i - 1];
		
		semiperimeter = (side_a_length + base_length + side_b_length) / 2;
		triangle_area = sqrt(semiperimeter * (semiperimeter - side_a_length) * (semiperimeter - base_length) * (semiperimeter - side_b_length));
		all_midpoint_distances[i] = 2 * triangle_area / base_length;
	}
	
	return all_midpoint_distances;
}

function get_max(array) {
	candidate = array[0];
	for (i = 1; i < array.length; i++) {
		candidate = maxOf(candidate, array[i]);
	}
	return candidate;
}

function get_min(array) {
	candidate = array[0];
	for (i = 1; i < array.length; i++) {
		candidate = minOf(candidate, array[i]);
	}
	return candidate;
}

// ---------------------------------------------------------------------------
// NEW FUNCTIONS (program 2.2)
// ---------------------------------------------------------------------------
function mkdirs(path) {
	File.makeDirectory(path);
	if (!File.exists(path)) {
		exit("Could not create the folder:\n" + path);
	}
}

// true if the pixel size is set in a unit other than pixels
function is_calibrated(unit) {
	cal = true;
	if (unit == "pixels") {
		cal = false;
	}
	if (unit == "pixel") {
		cal = false;
	}
	if (unit == "") {
		cal = false;
	}
	return cal;
}


// Pixel size check. The first image of the run: report the pixel width it reads and ask if it is correct, or ask for a
// replacement. A replacement (or a value for an image with no pixel size) is used for every image of this run; the
// image files are not changed.
function ensure_scale(name) {
	getPixelSize(unit, pw, ph);
	cal = true;
	if (unit == "pixels") {
		cal = false;
	}
	if (unit == "pixel") {
		cal = false;
	}
	if (unit == "") {
		cal = false;
	}
	micron = false;
	if (unit == "micron") {
		micron = true;
	}
	if (unit == "microns") {
		micron = true;
	}
	if (unit == "um") {
		micron = true;
	}
	if (unit == "\u00B5m") {
		micron = true;
	}
	if (unit == "\u03BCm") {
		micron = true;
	}
	if (!px_checked) {
		px_checked = true;
		Dialog.create("Pixel size check");
		if (cal) {
			Dialog.addMessage("The image " + name + " reads a pixel width of " + d2s(pw, 5) + " " + unit + " per pixel\n(pixel height " + d2s(ph, 5) + ").");
			if (!micron) {
				Dialog.addMessage("The unit is not microns. Enter the pixel width in microns below.");
			}
			Dialog.addCheckbox("This pixel size is correct", micron);
			Dialog.addNumber("If it is not correct, enter the right pixel width (microns per pixel)", 0, 4, 8, "um");
		} else {
			Dialog.addMessage("The image " + name + " has no pixel size.\nArea filters (um^2), local threshold radii and seed sizes depend on it.");
			Dialog.addNumber("Enter the pixel width (microns per pixel)", 0, 4, 8, "um");
		}
		Dialog.addMessage("The value you accept or enter is used for every image in this run. Image files are not changed.");
		Dialog.show();
		ok = false;
		if (cal) {
			ok = Dialog.getCheckbox();
		}
		rv = Dialog.getNumber();
		if (cal && ok) {
			px_override = 0;
		} else {
			if (rv <= 0) {
				exit("A pixel width above 0 (microns per pixel) is needed. Run the macro again.");
			}
			px_override = rv;
		}
		if (px_override > 0) {
			print("Pixel size check: " + name + " read " + d2s(pw, 5) + " " + unit + " per pixel. The run uses " + px_override + " um per pixel.");
		} else {
			print("Pixel size check: " + name + " reads " + d2s(pw, 5) + " " + unit + " per pixel, accepted as correct.");
		}
	}
	if (px_override <= 0 && !cal) {
		Dialog.create("Pixel size needed");
		Dialog.addMessage("The image " + name + " has no pixel size, although the first image had one.");
		Dialog.addNumber("Enter the pixel width (microns per pixel)", 0, 4, 8, "um");
		Dialog.show();
		rv2 = Dialog.getNumber();
		if (rv2 <= 0) {
			exit("A pixel width above 0 (microns per pixel) is needed. Run the macro again.");
		}
		px_override = rv2;
	}
	if (px_override > 0) {
		run("Set Scale...", "distance=1 known=" + px_override + " pixel=1 unit=micron");
	}
}

// open an image for step 1 / 2: one channel, Z projection if needed, 8-bit; title "base_img".
// A selection becomes an overlay region; the overlay is held on the overlay clipboard (had_overlay).
function open_base(path) {
	open(path);
	ensure_scale(File.getName(path));
	if (selectionType() != -1) {
		if (Overlay.size < 1) {
			Overlay.addSelection;
		}
		run("Select None");
	}
	had_overlay = false;
	if (Overlay.size > 0) {
		Overlay.copy;
		had_overlay = true;
	}
	getDimensions(w, h, c, s, f);
	if (c > 1) {
		keep_channel(channel);
	}
	getDimensions(w, h, c, s, f);
	if (s * f > 1) {
		orig = getTitle();
		run("Z Project...", "projection=[Max Intensity]");
		zt = getTitle();
		selectImage(orig);
		close();
		selectImage(zt);
	}
	run("8-bit");
	run("Select None");
	rename("base_img");
}

// file name stem of a mask: image_thresholded.tif -> image
function mask_stem(maskfile) {
	st = File.getNameWithoutExtension(maskfile);
	if (endsWith(st, "_thresholded")) {
		st = substring(st, 0, lengthOf(st) - lengthOf("_thresholded"));
	}
	return st;
}

// find the original image that belongs to a mask (same name without "_thresholded"); "" if not found
function find_original(dir, stem) {
	fl = getFileList(dir);
	for (q = 0; q < fl.length; q++) {
		if (!endsWith(fl[q], "/")) {
			if (File.getNameWithoutExtension(fl[q]) == stem) {
				return dir + fl[q];
			}
		}
	}
	return "";
}

// STEP 1 for one image
function segment_image(dir, file, outdir, idx, total) {
	stem = File.getNameWithoutExtension(file);
	stamp("Step 1, image " + (idx + 1) + "/" + total + ": " + file);
	open_base(dir + file);
	getPixelSize(unit, pw, ph);
	getDimensions(w, h, c, s, f);
	row = Table.size("Areas");
	Table.set("Label", row, file, "Areas");
	Table.set("Area", row, w * pw * h * ph, "Areas");
	Table.set("Unit", row, unit, "Areas");
	sigma_scale = 1;
	radius_scale = 1;
	if (is_calibrated(unit)) {
		sigma_scale = 1 / pw;
		radius_scale = benchPixel / pw;
	}
	istube = (thr_type == "tubeness");
	src = "base_img";
	if (!istube) {
		selectImage("base_img");
		run("Duplicate...", "title=pp_img");
		apply_pp(pp_code);
		src = "pp_img";
	}
	selectImage(src);
	run("Duplicate...", "title=work");
	if (istube) {
		tube_cutoff = tube_cuts[0];
		tubeness_segment(tv_idx);
	} else {
		apply_threshold(thr_type, thr_method, thr_radius);
	}
	selectImage("work");
	ensure_binary();
	dopost = post_on;
	if (istube) {
		dopost = (tv_post[tv_idx] == 1);
	}
	if (dopost) {
		postprocess();
	}
	normalize_binary();
	selectImage("work");
	if (had_overlay) {
		Overlay.paste;
	}
	saveAs("Tiff", outdir + stem + "_thresholded");
	close("*");
	produced = Array.concat(produced, stem + "_thresholded.tif");
}

// number of particles at or above minpx (pixels^2) in the active mask "work"
function count_big(minpx) {
	selectImage("work");
	run("Select None");
	setThreshold(255, 255);
	run("Analyze Particles...", "size=" + minpx + "-Infinity pixel summarize");
	resetThreshold();
	nb = Table.get("Count", Table.size("Summary") - 1, "Summary");
	close("Summary");
	return nb;
}

// STEP 2 for one mask
function split_image(maskdir, maskfile, origdir, outdir, idx, total) {
	stem = mask_stem(maskfile);
	stamp("Step 2, image " + (idx + 1) + "/" + total + ": " + maskfile);
	orig = find_original(origdir, stem);
	if (orig == "") {
		print("   no original image named " + stem + " in " + origdir + ". This mask was not split and not passed on.");
		return;
	}
	open(maskdir + maskfile);
	ensure_scale(maskfile);
	rename("work");
	fix_lut();
	getPixelSize(unit, pw, ph);
	getDimensions(mw, mh, mc, ms, mf);
	div = 1;
	sigma_scale = 1;
	if (is_calibrated(unit)) {
		div = pw * ph;
		sigma_scale = 1 / pw;
	}
	split_min_px = maxOf(area_min / div, 1);
	open_base(orig);
	getDimensions(bw, bh, bc, bs, bf);
	if (bw != mw || bh != mh) {
		print("   the original and the mask of " + stem + " have different sizes. This mask was not split and not passed on.");
		close("*");
		return;
	}
	selectImage("work");
	count_particles();
	before = pm_pre;
	big_before = count_big(split_min_px);
	split_sigma_px = split_sigma_um * sigma_scale;
	selectImage("work");
	split_cells(split_mode);
	seed_removed = "NA";
	if (seed_req) {
		selectImage("work");
		seed_removed = require_seed(split_sigma_px, split_prom);
	}
	big_after = count_big(split_min_px);
	selectImage("work");
	row = Table.size("SplitLog");
	Table.set("Image", row, stem, "SplitLog");
	Table.set("Min_area_um2", row, area_min, "SplitLog");
	Table.set("All_particles_before_split", row, before, "SplitLog");
	Table.set("Particles_above_filter_before", row, big_before, "SplitLog");
	Table.set("Particles_cut", row, split_multi, "SplitLog");
	Table.set("Particles_above_filter_after", row, big_after, "SplitLog");
	Table.set("Extra_objects_above_filter", row, big_after - big_before, "SplitLog");
	Table.set("Percent_of_above_filter_cut", row, 100 * split_multi / maxOf(big_before, 1), "SplitLog");
	Table.set("Method", row, split_labels[split_mode], "SplitLog");
	Table.set("Seed_required", row, seed_req, "SplitLog");
	Table.set("Particles_removed_no_seed", row, seed_removed, "SplitLog");
	saveAs("Tiff", outdir + File.getNameWithoutExtension(maskfile));
	close("*");
	produced = Array.concat(produced, File.getNameWithoutExtension(maskfile) + ".tif");
}

function dependencies_ok(need_thr, need_tube, need_skel) {
	List.setCommands;
	req = newArray(0);
	if (need_thr) {
		req = Array.concat(req, "Auto Threshold", "Auto Local Threshold");
	}
	if (need_tube) {
		req = Array.concat(req, "Tubeness");
	}
	if (need_skel) {
		req = Array.concat(req, "Skeletonize (2D/3D)", "Analyze Skeleton (2D/3D)");
	}
	missing = "";
	for (i = 0; i < req.length; i++) {
		if (List.get(req[i]) == "") {
			missing = missing + "\n - " + req[i];
		}
	}
	morpho_ok = (List.get("Morphological Filters") != "");
	if (missing != "") {
		exit("These commands were not found in Fiji:" + missing + "\nInstall them (Help > Update...) or choose a different option.");
	}
}

function pick_folder(title, text) {
	showMessage(title, text);
	d = getDirectory(title);
	return d;
}

function pp_words() {
	w = "";
	if (bg_code != "") {
		w = w + "background removal " + bg_code + " (" + substring(bg_code, 0, 2) + ", " + replace(substring(bg_code, 2), "p", ".") + " um), ";
	}
	if (substring(pp_code, 1, 2) == "1") {
		w = w + "contrast stretch, ";
	}
	if (substring(pp_code, 3, 4) == "1") {
		w = w + "unsharp mask (radius " + us_radius + ", weight " + us_weight + "), ";
	}
	if (substring(pp_code, 5, 6) == "1") {
		w = w + "despeckle, ";
	}
	if (w == "") {
		return "none";
	}
	return substring(w, 0, lengthOf(w) - 2);
}

// ---------------------------------------------------------------------------
// MACRO STARTS HERE
// ---------------------------------------------------------------------------
setOption("BlackBackground", true);
run_start = getTime();

start_labels = newArray("Step 1: preprocess and threshold the original images", "Step 2: split touching cells in existing thresholded masks", "Step 3: measure single cells from existing final masks");
last_labels = newArray("Stop after step 1 (thresholded masks)", "Stop after step 2 (split masks)", "Run through step 3 (single-cell measurements)");
app_labels = newArray("Auto thresholding (global)", "Auto local thresholding", "Tubeness ridge filter", "Hysteresis thresholding (local low + global high)");
bg_labels = newArray("None", "Rolling ball", "Sliding paraboloid", "Gaussian divide (flat-field)", "White top-hat (needs MorphoLibJ)");
bg_kinds = newArray("", "RB", "SP", "GD", "TH");
tv_labels = newArray("TubeOrig: 5 sigmas, Phansalkar radius 200", "Tube3: 3 sigmas, Phansalkar radius 200", "Tube3Post: 3 sigmas, Phansalkar radius 200, plus Program 2 post-processing", "Tube3R100: 3 sigmas, Phansalkar radius 100");
split_labels = newArray("No splitting", "Soma-seeded split (recommended)");
pk_menu = newArray("(set every option myself in the next dialogs)",
	"C0U1D1_auto_Huang", "C0U0D0_auto_Huang", "C1U0D0_auto_Li",
	"C0U1D1_local_Niblack_r100", "C0U1D1_local_Mean_r100", "C0U1D1_local_Phansalkar_r100",
	"C0U0D0_local_Niblack_r100", "C0U0D0_local_Mean_r100", "C0U0D0_local_Phansalkar_r100",
	"C0U1D1_RB25_auto_Huang", "C0U1D1_RB25_local_Niblack_r100", "C0U1D1_RB25_local_Mean_r100", "C0U1D1_RB25_local_Phansalkar_r100",
	"C0U1D1_RB40_auto_Huang", "C0U1D1_RB40_local_Niblack_r100", "C0U1D1_RB40_local_Mean_r100", "C0U1D1_RB40_local_Phansalkar_r100",
	"C0U1D1_SP25_auto_Huang", "C0U1D1_SP25_local_Niblack_r100", "C0U1D1_SP25_local_Mean_r100", "C0U1D1_SP25_local_Phansalkar_r100",
	"C0U1D1_hyst_Niblack-hiOtsu_r100", "C0U1D1_hyst_Mean-hiOtsu_r100", "C0U1D1_hyst_Phansalkar-hiOtsu_r100",
	"TubeOrig_c15", "TubeOrig_c20", "TubeOrig_c25", "TubeOrig_c30", "TubeOrig_k5", "Tube3Post_c20", "Tube3Post_c25");
pk_variants = newArray("Soma-seeded split + seed requirement (_splitSoma_seedReq)", "Soma-seeded split (_splitSoma)", "No splitting (unsplit)");
pk_suffix = newArray("_splitSoma_seedReq", "_splitSoma", "");

// ---- dialog 1: welcome, first and last step
Dialog.create("MicrogliaMorphology Program 2.3");
Dialog.addMessage("Welcome to MicrogliaMorphology.");
Dialog.addMessage("Please run the TestImageSettingsPicker macro (AllOptions version) on a test image first.\nIts top options tell you the best settings for your images; you choose that option here.");
Dialog.addMessage("The three steps are: 1 preprocess and threshold, 2 split touching cells, 3 measure single cells.\nYou can begin at any step if the earlier steps are already done.");
Dialog.addChoice("Start at", start_labels, start_labels[0]);
Dialog.addChoice("Finish at", last_labels, last_labels[2]);
Dialog.addCheckbox("Create output folders automatically (next to the input folder)", true);
Dialog.show();
sl = Dialog.getChoice();
ll = Dialog.getChoice();
use_directory_creation = Dialog.getCheckbox();
start_step = 1;
last_step = 3;
for (q = 0; q < 3; q++) {
	if (start_labels[q] == sl) {
		start_step = q + 1;
	}
	if (last_labels[q] == ll) {
		last_step = q + 1;
	}
}
if (last_step < start_step) {
	exit("The last step (" + last_step + ") comes before the first step (" + start_step + "). Run the macro again.");
}

// ---- dialogs 2 and 3: step 1 settings (skipped when an option was taken from the Picker)
sel_app = app_labels[0];
sel_global = "Huang";
sel_local = "Niblack";
sel_tv = tv_labels[0];
tube_cut_list = "20";
// ---- dialog 1b: settings from the TestImageSettingsPicker
picked = false;
if (start_step <= 2) {
	Dialog.create("Settings from the TestImageSettingsPicker");
	Dialog.addMessage("Choose the option that ranked best in the Picker (Top20_Options.csv or AllOptions_Ranked.csv), or paste its Option name below.\nThe option sets preprocessing, background removal, the threshold or Tubeness, and (with the splitting variant) the splitting and seed requirement.\nThe Picker's area filter (Min_area_um2 column) is entered later, in the area filter dialog.");
	Dialog.addChoice("Picker option (base option)", pk_menu, pk_menu[0]);
	Dialog.addChoice("Splitting variant", pk_variants, pk_variants[0]);
	Dialog.addString("Or paste the full Option name (overrides the two lists above; leave blank to use them)", "", 55);
	Dialog.show();
	pk_sel = Dialog.getChoice();
	pk_var = Dialog.getChoice();
	pk_paste = String.trim(Dialog.getString());
	pk_name = "";
	if (pk_paste != "") {
		pk_name = pk_paste;
	} else if (pk_sel != pk_menu[0]) {
		pk_suf = "";
		for (q = 0; q < pk_variants.length; q++) {
			if (pk_variants[q] == pk_var) {
				pk_suf = pk_suffix[q];
			}
		}
		pk_name = pk_sel + pk_suf;
	}
	if (pk_name != "") {
		if (!parse_picker_name(pk_name)) {
			exit("The option name was not understood:\n" + pk_name + "\nUse a name from the Picker's Option column, for example C0U1D1_RB25_local_Mean_r100_splitSoma_seedReq, or choose from the lists.");
		}
		picked = true;
		sel_tv = tv_labels[tv_idx];
		if (start_step == 1) {
			Dialog.create("Microglia channel");
			Dialog.addMessage("Option: " + pk_name);
			Dialog.addNumber("Channel with the microglia signal", 1);
			Dialog.show();
			channel = Dialog.getNumber();
		}
	}
}

if (start_step == 1 && !picked) {
	Dialog.create("Step 1a: preprocessing");
	Dialog.addMessage("These steps are applied before thresholding. They are ignored by the Tubeness option.\nThe Program 2 standard is unsharp mask and despeckle (C0U1D1).");
	Dialog.addNumber("Channel with the microglia signal", 1);
	Dialog.addCheckbox("Contrast stretch (Enhance Contrast, saturated 0.35, normalize)", false);
	Dialog.addCheckbox("Unsharp mask", true);
	Dialog.addNumber("   unsharp mask radius", 3);
	Dialog.addNumber("   unsharp mask weight", 0.6);
	Dialog.addCheckbox("Despeckle", true);
	Dialog.addMessage("Background removal (optional, applied first). In the benchmark, rolling ball 25-40 um and sliding paraboloid 25 um helped\nat low and medium background; Gaussian subtract and band-pass hurt. Not used by Tubeness.");
	Dialog.addChoice("Background removal", bg_labels, bg_labels[0]);
	Dialog.addNumber("   background size (um; larger than the biggest cell, 25 to 40 is typical)", 25);
	Dialog.show();
	channel = Dialog.getNumber();
	use_c = Dialog.getCheckbox();
	use_u = Dialog.getCheckbox();
	us_radius = Dialog.getNumber();
	us_weight = Dialog.getNumber();
	bg_size = Dialog.getNumber();
	use_d = Dialog.getCheckbox();
	pp_code = "C" + use_c + "U" + use_u + "D" + use_d;
	sel_bg = Dialog.getChoice();
	bg_code = "";
	for (q = 1; q < bg_labels.length; q++) {
		if (bg_labels[q] == sel_bg) {
			if (bg_size <= 0) {
				exit("The background size must be larger than 0 um.");
			}
			bg_code = bg_kinds[q] + numtag(bg_size);
		}
	}

	Dialog.create("Step 1b: segmentation");
	Dialog.addChoice("Approach", app_labels, app_labels[0]);
	Dialog.addMessage("Auto thresholding (global):");
	Dialog.addChoice("   global method", valid_auto, "Huang");
	Dialog.addMessage("Auto local thresholding:");
	Dialog.addChoice("   local method", valid_local, "Niblack");
	Dialog.addNumber("   radius (as in the Picker option name, e.g. 100)", 100);
	Dialog.addMessage("Tubeness ridge filter (slow on large images):");
	Dialog.addChoice("   variant", tv_labels, tv_labels[0]);
	Dialog.addString("   minimum response: a number such as 20, or noise-relative such as k5", "20", 8);
	Dialog.addNumber("   soma layer: mean + N x SD", 2);
	Dialog.addMessage("Hysteresis thresholding: uses the local method and radius above as the permissive (low) threshold and keeps only particles\nthat also contain a pixel of a strict global (high) threshold. Removes faint background blobs.");
	Dialog.addChoice("   hysteresis high (global) method", valid_auto, "Otsu");
	Dialog.addMessage("Program 2 post-processing (Despeckle, Close-, Remove Outliers) is always applied to the global and local options.\nTubeness uses the post-processing of its variant.");
	Dialog.show();
	sel_app = Dialog.getChoice();
	sel_global = Dialog.getChoice();
	sel_local = Dialog.getChoice();
	thr_radius = Dialog.getNumber();
	sel_tv = Dialog.getChoice();
	sel_hi = Dialog.getChoice();
	tube_cut_list = Dialog.getString();
	soma_sd = Dialog.getNumber();
	thr_type = "auto";
	thr_method = canon_method(sel_global, valid_auto, "Auto Threshold");
	if (sel_app == app_labels[1]) {
		thr_type = "local";
		thr_method = canon_method(sel_local, valid_local, "Auto Local Threshold");
	}
	if (sel_app == app_labels[2]) {
		thr_type = "tubeness";
		thr_method = tv_name[0];
		bg_code = "";
	}
	if (sel_app == app_labels[3]) {
		thr_type = "hyst";
		hi_method = canon_method(sel_hi, valid_auto, "Auto Threshold");
		thr_method = canon_method(sel_local, valid_local, "Auto Local Threshold") + "-hi" + hi_method;
		if (thr_radius <= 0) {
			exit("Hysteresis needs a local radius larger than 0.");
		}
	}
	for (q = 0; q < tv_labels.length; q++) {
		if (tv_labels[q] == sel_tv) {
			tv_idx = q;
		}
	}
	if (thr_type == "tubeness") {
		thr_method = tv_name[tv_idx];
		parse_cut_list();
		if (tube_cuts.length > 1) {
			exit("Enter a single Tubeness minimum response, for example 20 or k5.");
		}
	}
}

// ---- dialog 4: step 2 settings
step2_in_range = false;
if (start_step <= 2) {
	if (last_step >= 2) {
		step2_in_range = true;
	}
}
if (step2_in_range && picked) {
	if (split_mode == 0 && !seed_req && start_step == 2) {
		exit("The Picker option you chose has no splitting and no seed requirement, so there is nothing to do at step 2. Choose a splitting variant, or start at step 1.");
	}
}
if (step2_in_range && !picked) {
	Dialog.create("Step 2: splitting touching cells");
	Dialog.addMessage("Splitting replaces the upper area filter. Only particles at or above the minimum area are split.\nSoma-seeded: one seed per soma, taken from the blurred original image; a cell with branches is not cut.");
	Dialog.addChoice("Method", split_labels, split_labels[1]);
	Dialog.addNumber("Soma-seeded: seed blur sigma (um)", 3);
	Dialog.addNumber("Soma-seeded: prominence (8-bit grey levels)", 8);
	Dialog.addCheckbox("Require a soma seed: remove particles that contain no soma seed (non-cell objects)", false);
	Dialog.addMessage("In the benchmark this removed about half of the non-cell particles at a small cost to cell recovery.\nIt uses the seed blur and prominence above, and is applied after splitting.");
	Dialog.show();
	seed_req = Dialog.getCheckbox();
	sm = Dialog.getChoice();
	split_sigma_um = Dialog.getNumber();
	split_prom = Dialog.getNumber();
	split_mode = 0;
	if (sm == split_labels[1]) {
		split_mode = 1;
	}
	if (split_mode == 0 && !seed_req && start_step == 2) {
		exit("You chose to start at step 2 but no splitting method and no seed requirement. Run the macro again and choose one.");
	}
}
do_step1 = (start_step == 1);
do_step2 = false;
if (step2_in_range) {
	if (split_mode > 0 || seed_req) {
		do_step2 = true;
	}
}
do_step3 = (last_step >= 3);

// ---- dialog 5: area filters and measurement options
do_channel_quantification = false;
quantification_channel = 1;
if (do_step2 || do_step3) {
	Dialog.create("Cell area filters and measurements");
	Dialog.addMessage("Areas are in um^2 (images must have their pixel size set in microns).\nIf you chose a Picker option, use its best area filter (Min_area_um2 column of the Picker ranking).");
	Dialog.addNumber("Lower cell area filter (um^2)", 100);
	Dialog.addMessage("WARNING: the upper filter is no longer needed. Touching cells are separated in step 2.\nSet it only to remove large debris. Leave at 0 for no upper filter.");
	Dialog.addNumber("Upper cell area filter (um^2; 0 = none)", 0);
	if (do_step3) {
		Dialog.addCheckbox("Do your images have ROIs traced?", true);
		Dialog.addCheckbox("Quantify a fluorescence signal in the microglia?", false);
		Dialog.addNumber("   if yes, in which channel?", 1, 0, 3, "");
	}
	Dialog.show();
	area_min = Dialog.getNumber();
	area_max = Dialog.getNumber();
	if (do_step3) {
		roichoice = Dialog.getCheckbox();
		do_channel_quantification = Dialog.getCheckbox();
		quantification_channel = Dialog.getNumber();
	}
	if (area_max > 0 && area_max <= area_min) {
		exit("The upper area filter must be larger than the lower filter, or 0 for none.");
	}
}

// ---- summary
sum_txt = "Steps: " + start_step + " to " + last_step;
if (do_step1) {
	sum_txt = sum_txt + "\nPreprocessing: " + pp_words();
	if (thr_type == "auto") {
		sum_txt = sum_txt + "\nThreshold: auto (global) " + thr_method;
	}
	if (thr_type == "local") {
		sum_txt = sum_txt + "\nThreshold: auto local " + thr_method + ", radius " + thr_radius;
	}
	if (thr_type == "hyst") {
		sum_txt = sum_txt + "\nThreshold: hysteresis, local " + thr_method + ", radius " + thr_radius;
	}
	if (thr_type == "tubeness") {
		sum_txt = sum_txt + "\nTubeness: " + sel_tv + ", minimum response " + tube_cut_list;
	}
}
if (do_step2) {
	sum_txt = sum_txt + "\nSplit: " + split_labels[split_mode];
	if (split_mode == 1) {
		sum_txt = sum_txt + " (sigma " + split_sigma_um + " um, prominence " + split_prom + ")";
	}
	if (seed_req) {
		sum_txt = sum_txt + "\nSoma seed required: particles with no seed are removed";
	}
}
if (do_step2 || do_step3) {
	sum_txt = sum_txt + "\nLower area filter: " + area_min + " um^2";
	if (area_max > 0) {
		sum_txt = sum_txt + "\nUpper area filter: " + area_max + " um^2";
	} else {
		sum_txt = sum_txt + "\nUpper area filter: none";
	}
}
Dialog.create("Summary of your settings");
Dialog.addMessage(sum_txt);
Dialog.addMessage("Choose the folders next.");
Dialog.show();

need_thr = false;
need_tube = false;
if (do_step1) {
	if (thr_type == "tubeness") {
		need_tube = true;
	} else {
		need_thr = true;
	}
}
dependencies_ok(need_thr, need_tube, do_step3);
if (do_step1 && startsWith(bg_code, "TH")) {
	if (!morpho_ok) {
		exit("White top-hat background removal needs the MorphoLibJ plugin (Help > Update... > Manage update sites > IJPB-plugins).");
	}
}

// ---- folders
input_dir = "";
orig_dir = "";
mask_dir = "";
thresholded_dir = "";
split_dir = "";
data_output = "";
if (start_step == 1) {
	input_dir = pick_folder("Choose the folder of original images", "Next, choose the folder that contains your original input images.");
	orig_dir = input_dir;
	parent_dir = File.getParent(input_dir);
	files = list_images(input_dir);
}
if (start_step == 2) {
	mask_dir = pick_folder("Choose the folder of thresholded masks", "Next, choose the folder with the thresholded masks (the files that end in _thresholded.tif).");
	orig_dir = pick_folder("Choose the folder of original images", "Next, choose the folder with the original images. They are needed for the soma seeds.");
	parent_dir = File.getParent(mask_dir);
	files = list_images(mask_dir);
}
if (start_step == 3) {
	mask_dir = pick_folder("Choose the folder of final masks", "Next, choose the folder with the final masks to measure (thresholded or split masks).");
	if (do_channel_quantification) {
		orig_dir = pick_folder("Choose the folder of original images", "Next, choose the folder with the original fluorescence images for the signal quantification.");
	}
	parent_dir = File.getParent(mask_dir);
	files = list_images(mask_dir);
}
if (files.length == 0) {
	exit("No tif, png or jpg images were found in the first input folder.");
}
if (do_step1) {
	if (use_directory_creation) {
		thresholded_dir = parent_dir + File.separator + "ThresholdedImages" + File.separator;
		mkdirs(thresholded_dir);
	} else {
		thresholded_dir = pick_folder("Choose the folder for thresholded images", "Next, choose the output folder for the thresholded images.");
	}
}
if (do_step2) {
	if (use_directory_creation) {
		split_dir = parent_dir + File.separator + "SplitImages" + File.separator;
		mkdirs(split_dir);
	} else {
		split_dir = pick_folder("Choose the folder for split masks", "Next, choose the output folder for the split masks.");
	}
}
if (do_step3) {
	if (use_directory_creation) {
		data_output = parent_dir + File.separator + "MeasurementResults" + File.separator;
		mkdirs(data_output);
	} else {
		data_output = pick_folder("Choose the folder for measurement results", "Next, choose the output folder for the measurement results.");
	}
}

// ---- image range
Dialog.create("Images to process");
Dialog.addMessage("The first step of this run will process the " + files.length + " images in the input folder.\nImage 1 is " + files[0] + ".");
Dialog.addNumber("Start at image", 1);
Dialog.addNumber("Stop at image", files.length);
Dialog.show();
startAt = maxOf(Dialog.getNumber(), 1);
endAt = minOf(Dialog.getNumber(), files.length);
if (endAt < startAt) {
	exit("Stop at image is smaller than start at image.");
}
cur_files = Array.slice(files, startAt - 1, endAt);

// ---- record the settings
rec_dir = parent_dir;
getDateAndTime(yr, mo, dw, dm, hr, mi, sc, ms);
stampname = "" + yr + IJ.pad(mo + 1, 2) + IJ.pad(dm, 2) + "-" + IJ.pad(hr, 2) + IJ.pad(mi, 2);
f = File.open(rec_dir + File.separator + "FinalDatasetParameters_" + stampname + ".txt");
print(f, "MicrogliaMorphology Program 2.3, steps " + start_step + " to " + last_step);
first_in = input_dir;
if (start_step > 1) {
	first_in = mask_dir;
}
print(f, "First input folder = " + first_in);
if (do_step1) {
	print(f, "Microglia channel = " + channel);
	print(f, "Preprocessing = " + pp_code + " (" + pp_words() + ")");
	armname = pp_code;
	if (bg_code != "") {
		armname = armname + "_" + bg_code;
	}
	armname = armname + "_" + thr_type + "_" + thr_method;
	if (thr_type == "hyst") {
		armname = armname + "_r" + thr_radius;
		print(f, "Hysteresis: local low threshold " + substring(thr_method, 0, indexOf(thr_method, "-hi")) + " radius " + thr_radius + " px at " + benchPixel + " um/px; global high threshold " + hi_method);
	}
	if (thr_type == "local") {
		armname = armname + "_r" + thr_radius;
		print(f, "Local threshold radius = " + thr_radius + " px at " + benchPixel + " um/px");
	}
	if (thr_type == "tubeness") {
		cs = tube_cut_list;
		if (startsWith(toLowerCase(cs), "k")) {
			armname = tv_name[tv_idx] + "_" + toLowerCase(cs);
		} else {
			armname = tv_name[tv_idx] + "_c" + cs;
		}
		print(f, "Tubeness variant = " + sel_tv + ", minimum response = " + cs + ", soma layer SD = " + soma_sd);
	}
	print(f, "TestImageSettingsPicker option name = " + armname);
	print(f, "Program 2 post-processing = always on for global and local thresholds");
}
if (do_step2) {
	print(f, "Splitting = " + split_labels[split_mode] + ", seed sigma = " + split_sigma_um + " um, prominence = " + split_prom);
	print(f, "Soma seed required = " + seed_req);
}
if (do_step2 || do_step3) {
	print(f, "Lower cell area filter (um^2) = " + area_min);
	print(f, "Upper cell area filter (um^2, 0 = none) = " + area_max);
}
File.close(f);

// ---- pixel size: ask now if the first image has none
open(first_in + cur_files[0]);
ensure_scale(cur_files[0]);
close("*");

// ---- run
setBatchMode(true);
run("Text Window...", "name=[Progress] width=60 height=10");
setLocation(10, 10);
print("\\Clear");
curdir = "";

if (do_step1) {
	Table.create("Areas");
	produced = newArray(0);
	for (i = 0; i < cur_files.length; i++) {
		print("[Progress]", "\\Update:Step 1, thresholding\nimage " + (i + 1) + "/" + cur_files.length + ": " + cur_files[i]);
		segment_image(input_dir, cur_files[i], thresholded_dir, i, cur_files.length);
		run("Collect Garbage");
	}
	Table.save(rec_dir + File.separator + "Areas.csv", "Areas");
	close("Areas");
	cur_files = produced;
	curdir = thresholded_dir;
	print("Step 1 finished: " + cur_files.length + " masks in " + thresholded_dir);
} else {
	curdir = mask_dir;
}

if (do_step2) {
	Table.create("SplitLog");
	produced = newArray(0);
	for (i = 0; i < cur_files.length; i++) {
		print("[Progress]", "\\Update:Step 2, splitting\nimage " + (i + 1) + "/" + cur_files.length + ": " + cur_files[i]);
		split_image(curdir, cur_files[i], orig_dir, split_dir, i, cur_files.length);
		run("Collect Garbage");
	}
	Table.save(rec_dir + File.separator + "SplitLog.csv", "SplitLog");
	close("SplitLog");
	cur_files = produced;
	curdir = split_dir;
	print("Step 2 finished: " + cur_files.length + " split masks in " + split_dir);
}

if (do_step3) {
	skipped_files = newArray();
	for (i = 0; i < cur_files.length; i++) {
		orig_path = "";
		if (do_channel_quantification) {
			orig_path = find_original(orig_dir, mask_stem(cur_files[i]));
			if (orig_path == "") {
				print("No original image found for " + cur_files[i] + ", so no signal quantification can be done for it.");
			}
		}
		this_q = do_channel_quantification;
		if (orig_path == "") {
			this_q = false;
		}
		print("[Progress]", "\\Update:Step 3, measuring\nimage " + (i + 1) + "/" + cur_files.length + ": " + cur_files[i]);
		skipping = cellROI(curdir, data_output, cur_files[i], area_min, area_max, this_q, orig_path, quantification_channel, i, cur_files.length);
		skipped_files = Array.concat(skipped_files, skipping);
		run("Collect Garbage");
	}
	skipped_files = Array.deleteValue(skipped_files, "");
	print("Finished analysing cells. If there were any problems with regions within an image they are listed here:\n" + String.join(skipped_files, "\n"));
}

setBatchMode(false);
close("*");
close("ROI Manager");
print("[Progress]", "\\Update:Complete. See Log for errors.");
selectWindow("Progress");
run("Close");
stamp("done!");
showMessage("MicrogliaMorphology", "Finished steps " + start_step + " to " + last_step + ".\nSettings used are saved in FinalDatasetParameters_" + stampname + ".txt in:\n" + rec_dir);
