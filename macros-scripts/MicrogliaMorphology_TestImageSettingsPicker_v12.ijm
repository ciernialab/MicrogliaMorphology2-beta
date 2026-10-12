//// MicrogliaMorphology: TEST-IMAGE SETTINGS PICKER (v12, built on preprocessing benchmark v10)
//// v12: the distance-map watershed split was removed (soma-seeded split only), and the macro reports the pixel size it reads and asks
////   if it is correct (or for a replacement).
////
//// PURPOSE. Run this AFTER the Image Quality Check macro. It processes ONE test image with a short list of
//// options chosen from the synthetic-image benchmarking for your kind of image, and saves a MONTAGE so you can
//// look at the masks side by side and choose the settings to batch run on the whole experiment.
////
//// HOW TO USE
////   1. Open a representative test image (one you have already run through the Image Quality Check macro).
////   2. Run this macro. The "My image has" dropdown is preselected from the last Image Quality Check result;
////      change it if you disagree. Choices: low / medium / high background x high / low SNR, or "Not sure: broad
////      comparison". Each choice builds a different set of options (see RECOMMENDATIONS below).
////   3. Wait. Outputs go in a new folder next to the image: SettingsTest_<image>/
////        ReviewMontage_<image>_ALL.png      rows = options, columns = minimum area filters (opens when done)
////        ReviewMontage_<image>_min<..>.png  one montage per filter, first tile = the raw image
////        SettingsKey.txt                    tile number -> the exact settings of every option
////        PreprocessBenchmark_Results.csv    particle counts etc. for each option and filter
////        Masks/<option>/                    the binary mask of every option
////   4. Colour code in the panels: white = particle kept by the area filter, red = removed (too small),
////      yellow = line where touching cells were cut. Look for: ramified cells whole (processes present), few red or
////      white non-cell particles in the background, touching cells separated, and thin branches not lost.
////   5. Put the chosen settings into your batch pipeline (SettingsKey.txt lists them).
////
//// OPTIONS COMPARED (names are C<contrast stretch>U<unsharp mask>D<despeckle>):
////   C0U1D1  Program 2 standard preprocessing (unsharp mask radius 3, weight 0.6, despeckle; no contrast stretch)
////   C0U0D0  no preprocessing        C1U0D0  contrast stretch only
////   Threshold methods: Huang, Li (global); Niblack, Mean, Phansalkar (local, radius 100 px at 0.3447 um/px)
////   Tubeness: TubeOrig (5 sigmas) at fixed minimum responses, then Phansalkar r200
////   Every option is run with and without the soma-seeded split unless you choose otherwise.
////   Local-threshold radii are given for 0.3447 um/px and are rescaled to your pixel size when the image is calibrated.
////
//// RECOMMENDATIONS BY IMAGE TYPE (from the synthetic benchmark; scores are equal-recovery scores, max 1)
////   Low background, high SNR     Tubeness cutoff 20 gave the best score (about 0.6) with very few non-cell particles.
////   Low background, low SNR      Tubeness lost its advantage; local thresholds (Niblack, Mean) with unsharp mask were more robust.
////   Medium background            Huang gave scores close to Niblack with about half the non-cell particles; Niblack and Mean
////                                recover more cells but keep many non-cell particles; use a 100 um^2 or larger filter.
////   High background              all methods lost ramified and rod cells; Phansalkar kept the fewest non-cell particles;
////                                use a larger filter (130-150 um^2) and check the result by eye.
//// These are starting points from synthetic images. The montage is how you confirm them on your own tissue.
////
//// ------------------------------------------------------------------------------------------------------------
//// Notes carried over from v10 (the segmentation, splitting and review-panel code is unchanged):

//// MicrogliaMorphology: preprocessing benchmark v10
//// v10: NOISE-RELATIVE TUBENESS CUTOFF. A fixed minimum response (0-255, relative to each image's strongest ridge) moved
////   with staining brightness on the synthetic set. The Tubeness cutoff list now accepts two kinds of entry:
////     15     absolute cutoff on the 0-255 scale (as before)
////     k5     noise-relative: cutoff = median + 5 x 1.4826 x MAD of the response, computed separately for every sigma on the
////            non-zero ridge pixels of that image (the lowest histogram bin, where Tubeness is exactly 0, is excluded).
////            The median and MAD track the background ridge level, so the cutoff rises with background and is not
////            moved by bright cells. Arm names end in _c15 or _k5; the table has Tube_cutoff (c15 / k5) and
////            Tube_effective_cut (the 0-255 value actually applied, per sigma).
////   New run mode "Noise-relative Tubeness test": TubeOrig with 15, k3, k5, k8, k12, plus Huang and Niblack r100 as references.
////
//// (v9 notes follow)
//// MicrogliaMorphology: preprocessing benchmark v9
//// v9: SHORTLIST MODE for real images. The first dialog asks for a run mode. "Shortlist" runs only the options that
////   did best against the synthetic ground truth (about 35 arms) and skips the page of experiment settings:
////     thresholds (Program 2 preprocessing C0U1D1 unless stated), each with and without the soma-seeded split:
////       C0U1D1_local_Niblack_r100   Program 2 standard (the reference; its unsplit arm is Program 2 with only a lower filter)
////       C0U1D1_auto_Huang           best balance of cells recovered and non-cell particles
////       C1U0D0_auto_Li              cleanest arm that still recovers ramified cells (contrast stretch only)
////       C0U1D1_local_Mean_r100      most cells recovered, but many non-cell particles
////       C0U1D1_local_Phansalkar_r100  cleanest, but loses thin branches
////     Tubeness: TubeOrig and Tube3Post at minimum responses 12, 15 and 18 (15 was best on the synthetic image;
////       the neighbours show how sensitive the cutoff is on your images)
////     Soma split seeds: sigma 3 and 2 um x prominence 8 and 12 for Niblack, Huang, Li and Mean; Phansalkar and Tubeness use 3 / 8.
////   Minimum area filters default to 50, 100, 130 um2. One montage per filter is saved, plus (new) one COMBINED
////   montage per image with every arm and filter: rows = arms, columns = minimum area filters (ReviewMontage_<image>_ALL.png).
////   Choose "Full benchmark" to get all the v8 options back.
////
//// Three experiments in one run, one results table (one row per image x arm) for R.
////
//// A. Program 2 preprocessing, every on/off combination of its three steps:
////      C = contrast stretch (Enhance Contrast, saturated 0.35, WITH normalize)
////      U = Unsharp Mask (radius / weight set in the dialog)
////      D = Despeckle
////    Arm names are C<0|1>U<0|1>D<0|1>. Program 2's own preprocessing is C0U1D1: its
////    Enhance Contrast call has no normalize option, so it only changes the display range
////    and leaves the pixel values (and so the thresholds) unchanged. C1 is a real stretch.
////    Each combination is crossed with the thresholds given for experiment A.
//// B. Tubeness variants (on the raw 8-bit image), each changing one thing relative to Tube3:
////      TubeOrig    5 sigmas (0.9,0.5,0.1,0.05,0.005), Phansalkar r200   (current arm)
////      Tube3       sigmas 0.9,0.5,0.1 only, Phansalkar r200
////      Tube3Post   Tube3 plus Program 2 post-processing
////      Tube3R100   Tube3 with Phansalkar r100
////    (v2's Tube3Global_<method> arms, a global threshold on the Tubeness response, were removed in v3.)
////    Tubeness responses are reused between arms.
////    Every stage is timed and logged with a clock time (see T_ columns and the Log).
//// C. Global (Auto Threshold) vs local (Auto Local Threshold) methods and radii, all on
////    Program 2 preprocessing (C0U1D1).
//// v8: TUBENESS CUTOFF SWEEP. The minimum Tubeness response (0-255, applied before the local threshold) can
////   be a list, e.g. 15,20,25,30. Each Tubeness variant is run at every cutoff and named
////   <variant>_c<cutoff> (a single value keeps the plain name). A higher cutoff drops weak ridges
////   (haze, thin background fibres) before thresholding. The Tubeness filter itself is computed once per
////   sigma and image and reused for all cutoffs (the cached response is not yet gated).
//// v7: SEED SWEEP. The soma-seeded split can test several seed blur sigmas and prominences. Give lists
////   (e.g. 3,2,4 and 8,5,12): every sigma x prominence pair becomes its own arm, named
////   <arm>_splitSoma_s<sigma>_p<prominence>. To keep the run short, the sweep only applies to arms whose
////   name contains one of the "sweep only" entries; every other arm is split once with the FIRST sigma
////   and FIRST prominence in the lists (so put your default first). A single value in each list = no sweep.
//// SPLITTING TOUCHING CELLS (replaces the upper area filter): set Maximum area to 0 and choose splitting.
//// Splitting adds a copy of every arm, named <arm> and <arm>_splitSoma. Thresholding and post-processing are done once per arm and reused by its split copies.
////   splitSoma  seeds = one maximum per soma: the raw image is blurred (sigma about a soma radius, set in
////              um), local maxima (prominence in 8-bit grey levels) are found, and the mask is cut along
////              the watershed lines between the maxima. Thin branches have no maximum of their own, so a
////              branched cell is not cut; two bright somas joined by touching processes are.
//// Only particles at or above the minimum area are ever split. soma mode additionally cuts only particles
//// that contain two or more seeds, so a single cell is never trimmed at the tips of its processes.
//// Cut lines are shown in yellow in the review panels.
//// Columns to choose a condition: N_in_filter (cells kept), Kept_area_fraction (share of foreground
//// area inside kept particles; high = the filter drops little of the morphology), Largest_particle_px
//// and Area_P95_px (unsplit blobs show here), N_pre_split vs N_particles (how many cuts were made).
//// SEVERAL MINIMUM AREA FILTERS: give a comma separated list (default 100,130,150 um^2). Thresholding and
//// splitting are done once per arm; the particle metrics and the review panel are made for each filter.
//// The results table gets one row per arm x filter (column Min_area; Area_lo_px is the same in pixels), and
//// each filter gets its own montage: ReviewMontage_<image>_min<value>um2.png (panels in
//// ReviewPanels/<image>/min<value>um2/). Splitting only touches particles at or above the smallest filter.
//// Program 2 post-processing (Despeckle, Close-, Remove Outliers) is applied to all arms
//// except the Tubeness variants that do not say Post.
////
//// TIMING COLUMNS (ms; NA where a stage does not apply)
////   T_preprocess_ms  preprocessing for this combination (computed once, shared by its arms)
////   T_soma_ms, T_tubeness_ms, T_gate_ms, T_threshold_ms, T_closing_ms   Tubeness stages
////   T_threshold_ms   also the threshold step of the other arms
////   T_post_ms        Program 2 post-processing;  T_metrics_ms  measurements;  T_total_ms  whole arm
////   Sigma_times_ms   total time for each sigma (sigma:ms)
////
//// METRICS (whole image; areas in pixels), as in v1: foreground fraction, particle counts,
//// area / solidity / circularity, skeleton pixels, overlap with ground truth and with
//// Program 2 thresholded images, FG_intensity_ratio, Detail_skipped, Binarised_fix.
////
//// REVIEW PANELS: for every arm a colour-coded panel is saved in ReviewPanels/<image>/ and all
//// panels of an image are tiled into ReviewMontage_<image>.png. The first tile (000_Original) is
//// the raw 8-bit image for the same cropped region, for comparison. White = particle inside the area
//// filter, red = at or below the minimum, cyan = at or above the maximum, yellow = split line. Nothing is removed from
//// the masks. Method names are matched case-insensitively (NiBlack is read as Niblack).
////
//// REQUIRES (Fiji): Auto Threshold, Auto Local Threshold, Skeletonize (2D/3D) if skeleton is on,
////   Tubeness for experiment B, MorphoLibJ optional (Close- is used if absent).
//// NOTES: sets "Black background" to true; images are analysed whole (ROIs ignored); inputs
////   tif/tiff/png/jpg; the results CSV is rewritten after every arm; use the crop option
////   for a first test of whole-slide images.

// ---------------------------------------------------------------------------
// GLOBALS
// ---------------------------------------------------------------------------
var arm_name = newArray(0);
var arm_pp = newArray(0);
var arm_type = newArray(0);
var arm_method = newArray(0);
var arm_radius = newArray(0);
var arm_tv = newArray(0);
var arm_split = newArray(0);
var arm_base = newArray(0);
var split_on = newArray(1, 1);
var px_checked = false;
var px_override = 0;
var split_sigma_um = 3;
var split_prom = 8;
var split_sigma_px = 12;
var arm_sig = newArray(0);
var arm_prom = newArray(0);
var sig_list = "3,2,4";
var prom_list = "8,5,12";
var sweep_only = "C0U1D1_auto_Huang,C0U1D1_local_Mean_r100,C0U1D1_local_Niblack_r100";
var sig_vals = newArray(3);
var prom_vals = newArray(8);
var sigma_scale = 1;
var pm_pre = "NA";
var split_multi = "NA";
var tm_split = "NA";
var has_cut = false;
var cached_base = "";
var pm_keptarea = -1;
var pm_largest = -1;
var pm_p95 = -1;

// Tubeness variant definitions
var tv_name = newArray("TubeOrig", "Tube3", "Tube3Post", "Tube3R100");
var tv_sigmas = newArray("0.9,0.5,0.1,0.05,0.005", "0.9,0.5,0.1", "0.9,0.5,0.1", "0.9,0.5,0.1");
var tv_thr = newArray("local", "local", "local", "local");
var tv_radius = newArray(200, 200, 200, 100);
var tv_post = newArray(0, 0, 1, 0);
var tv_on = newArray(1, 1, 1, 1);

var expA = true;
var expB = true;
var expC = true;
var a_global = "";
var a_local = "";
var a_radii = "";
var c_global = "";
var c_local = "";
var c_radii = "";
var us_radius = 3;
var us_weight = 0.6;
var soma_sd = 2;
var tube_cutoff = 10;
var run_short = false;
var do_combined = true;
var comb_scale = 0.5;
var min_def = "100,130,150";
var tube_cut_list = "15,20,25,30";
var tube_cuts = newArray(1);
var cur_cut = 0;
var arm_cut = newArray(0);

var min_area = 0;
var min_list = "100,130,150";
var flt_val = newArray(0);
var flt_px = newArray(0);
var flt_tag = newArray(0);
var split_min_px = 1;
var flt_label = "";
var rev_root = "";
var max_area = 0;
var max_eff = 1000000000000;
var channel = 1;
var crop_size = 0;
var do_skeleton = false;
var save_masks = true;
var use_gt = false;
var gt_suffix = "_GT";
var use_ref = false;
var max_particles = 150000;
var area_lo = 0;
var area_hi = 1000000000000;
var area_units_cal = true;
var do_review = true;
var review_crop = 1200;
var panel_px = 600;
var montage_cols = 6;
var rev_dir = "";
var valid_auto = newArray("Default", "Huang", "Huang2", "Intermodes", "IsoData", "IJ_IsoData", "Li", "MaxEntropy", "Mean", "MinError(I)", "Minimum", "Moments", "Otsu", "Percentile", "RenyiEntropy", "Shanbhag", "Triangle", "Yen");
var valid_local = newArray("Bernsen", "Contrast", "Mean", "Median", "MidGrey", "Niblack", "Otsu", "Phansalkar", "Sauvola");

var in_dir = "";
var out_dir = "";
var gt_dir = "";
var ref_dir = "";
var mask_root = "";

var morpho_ok = false;
var warned_close = false;
var run_start = 0;
var cached_pp = "";
var tm_pp_cache = 0;
var reuse_tube = true;
var tbc_keys = newArray(0);
var tbc_tub = newArray(0);
var tbc_gate = newArray(0);
var tbc_med = newArray(0);
var tbc_mad = newArray(0);
var g_med8 = 0;
var g_mad8 = 0;
var g_cut_used = 0;
var eff_cut_str = "NA";
var run_mode = 0;
var tm_cached = false;
var g_tk = 0;
var g_tg = 0;

// per-arm timing
var tm_pp = "NA";
var tm_soma = "NA";
var tm_tub = "NA";
var tm_gate = "NA";
var tm_thr = "NA";
var tm_close = "NA";
var tm_post = "NA";
var tm_sigma_str = "NA";

// outputs
var m_dice = "NA";
var m_iou = "NA";
var m_prec = "NA";
var m_rec = "NA";
var pm_n = 0;
var pm_nin = 0;
var pm_nsmall = 0;
var pm_nbig = 0;
var pm_mean = "NA";
var pm_median = "NA";
var pm_solid = "NA";
var pm_circ = "NA";
var pm_skipped = false;
var fg_ratio = "NA";
var fixed_binary = false;



// ---------------------------------------------------------------------------
// v11: SETTINGS-TEST GLOBALS
// ---------------------------------------------------------------------------
var preset_names = newArray("Low background, high SNR", "Low background, low SNR", "Medium background, high SNR", "Medium background, low SNR", "High background, high SNR", "High background, low SNR", "Not sure: broad comparison");
var preset_idx = 6;
var rec_text = newArray(7);
var lead_pat = newArray("TubeOrig_c20", "C0U1D1_local_Mean_r100", "C0U1D1_auto_Huang", "C0U1D1_local_Niblack_r100", "C0U1D1_local_Phansalkar_r100", "C0U1D1_local_Phansalkar_r100", "C0U1D1_local_Niblack_r100");
var benchPixel = 0.3447;
var radius_scale = 1;
var last_pw = 1;
var last_unit = "pixels";
var seed_sweep = false;
var test_path = "";
var qc_note = "";
var user_win_title = "";
var do_mark = true;
var mark_n = 0;
var mark_x = newArray(0);
var mark_y = newArray(0);
var reg_x = 0;
var reg_y = 0;
var reg_w = 0;
var reg_h = 0;
var gc_single = 0;
var gc_merged_parts = 0;
var gc_in_merged = 0;
var gc_missed = 0;
var gc_noncell = 0;

// ---------------------------------------------------------------------------
// SMALL HELPERS
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

// log line with clock time and seconds since the run started
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

// return the exact plugin spelling of a method name (case-insensitive); stop with a message if unknown.
// Fiji ignores a misspelt method silently, which leaves the image unthresholded.
function canon_method(name, valid, plugin) {
	for (q = 0; q < valid.length; q++) {
		if (toLowerCase(valid[q]) == toLowerCase(name)) {
			return valid[q];
		}
	}
	exit("Unknown " + plugin + " method: " + name + "\nValid names: " + String.join(valid, ", "));
}

// canonical spelling for each name in a comma separated list; returns the cleaned list
function canon_list(str, valid, plugin) {
	items = split_list(str);
	res = newArray(items.length);
	for (z = 0; z < items.length; z++) {
		res[z] = canon_method(items[z], valid, plugin);
	}
	return String.join(res, ",");
}

function add_arm(pp, type, method, radius, tv) {
	if (type == "auto") {
		method = canon_method(method, valid_auto, "Auto Threshold");
	}
	if (type == "local") {
		method = canon_method(method, valid_local, "Auto Local Threshold");
	}
	nm = pp + "_" + type + "_" + method;
	if (radius > 0) {
		nm = nm + "_r" + radius;
	}
	if (type == "tubeness") {
		nm = method;
	}
	if (type == "tubeness" && tube_cuts.length > 1) {
		if (cur_cut < 0) {
			nm = nm + "_k" + (-cur_cut);
		} else {
			nm = nm + "_c" + cur_cut;
		}
	}
	nm = replace(nm, "\\(", "");
	nm = replace(nm, "\\)", "");
	for (q = 0; q < arm_name.length; q++) {
		if (arm_name[q] == nm) {
			return;
		}
	}
	arm_name = Array.concat(arm_name, nm);
	arm_pp = Array.concat(arm_pp, pp);
	arm_type = Array.concat(arm_type, type);
	arm_method = Array.concat(arm_method, method);
	arm_radius = Array.concat(arm_radius, radius);
	arm_tv = Array.concat(arm_tv, tv);
	cc = 0;
	if (type == "tubeness") {
		cc = cur_cut;
	}
	arm_cut = Array.concat(arm_cut, cc);
}

function add_threshold_arms(pp, gstr, lstr, rstr) {
	globals = split_list(gstr);
	locals = split_list(lstr);
	radii = split_list(rstr);
	for (k = 0; k < globals.length; k++) {
		add_arm(pp, "auto", globals[k], 0, -1);
	}
	for (k = 0; k < locals.length; k++) {
		for (r = 0; r < radii.length; r++) {
			add_arm(pp, "local", locals[k], parseFloat(radii[r]), -1);
		}
	}
}

function find_mask(dir, stem) {
	if (dir == "") {
		return "";
	}
	exts = newArray(".tif", ".tiff", ".png");
	for (e = 0; e < exts.length; e++) {
		p = dir + stem + exts[e];
		if (File.exists(p)) {
			return p;
		}
	}
	return "";
}

function tset(col, row, val) {
	Table.set(col, row, val, "Benchmark");
}


// ---------------------------------------------------------------------------
// POLARITY / BINARY CHECKS
// ---------------------------------------------------------------------------
// make "work" white objects (255) on black: the foreground must be brighter, on average,
// than the whole image (compared with the raw "base_img")
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

// make sure the active image holds only 0 and 255 (Close- fails otherwise)
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


// ---------------------------------------------------------------------------
// PREPROCESSING, THRESHOLDING, POST-PROCESSING
// ---------------------------------------------------------------------------
// pp is C<0|1>U<0|1>D<0|1>; steps run in Program 2's order: contrast, unsharp, despeckle
function apply_pp(pp) {
	run("Select None");
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
}

// Program 2 post-processing
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


// ---------------------------------------------------------------------------
// TUBENESS VARIANT (timed). Input: the active 8-bit image. Output: binary mask, same title.
// ---------------------------------------------------------------------------
// forget the cached Tubeness responses (called at the start and end of every image)
function clear_tube_cache() {
	for (q = 0; q < tbc_keys.length; q++) {
		if (isOpen("tbc_" + tbc_keys[q])) {
			close("tbc_" + tbc_keys[q]);
		}
	}
	tbc_keys = newArray(0);
	tbc_tub = newArray(0);
	tbc_gate = newArray(0);
	tbc_med = newArray(0);
	tbc_mad = newArray(0);
}

// Tubeness filter at one sigma, converted to 8-bit (not yet gated). Leaves "tb_feat"; g_tk = filter time.
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

// Zero every pixel of the active "tb_feat" below the cutoff (tube_cutoff >= 0: absolute 0-255; < 0: median + k x 1.4826 x MAD with k = -tube_cutoff). g_tg = gating time.
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


// ---------------------------------------------------------------------------
// METRICS
// ---------------------------------------------------------------------------
function particle_metrics() {
	run("Select None");
	pm_n = 0;
	pm_nin = 0;
	pm_nsmall = 0;
	pm_nbig = 0;
	pm_mean = "NA";
	pm_median = "NA";
	pm_solid = "NA";
	pm_circ = "NA";
	pm_skipped = false;
	pm_keptarea = -1;
	pm_largest = -1;
	pm_p95 = -1;
	setThreshold(255, 255);
	run("Analyze Particles...", "size=0-Infinity pixel summarize");
	resetThreshold();
	cnt = Table.get("Count", Table.size("Summary") - 1, "Summary");
	close("Summary");
	pm_n = cnt;
	if (cnt > max_particles) {
		pm_skipped = true;
		print("      " + cnt + " particles (more than " + max_particles + "): detailed metrics skipped");
		return;
	}
	if (cnt == 0) {
		return;
	}
	setThreshold(255, 255);
	run("Set Measurements...", "area shape redirect=None decimal=4");
	run("Analyze Particles...", "size=0-Infinity pixel display clear");
	resetThreshold();
	areas = Table.getColumn("Area", "Results");
	sols = Table.getColumn("Solidity", "Results");
	circs = Table.getColumn("Circ.", "Results");
	run("Clear Results");
	n = areas.length;
	Array.getStatistics(areas, almin, almax, almean, alsd);
	pm_largest = almax;
	ina = newArray(n);
	ins = newArray(n);
	inc = newArray(n);
	k = 0;
	for (j = 0; j < n; j++) {
		ar = areas[j];
		if (ar <= area_lo) {
			pm_nsmall++;
		} else if (ar >= area_hi) {
			pm_nbig++;
		} else {
			ina[k] = ar;
			ins[k] = sols[j];
			inc[k] = circs[j];
			k++;
		}
	}
	pm_nin = k;
	if (k > 0) {
		ina = Array.trim(ina, k);
		ins = Array.trim(ins, k);
		inc = Array.trim(inc, k);
		Array.getStatistics(ina, amin, amax, amean, asd);
		pm_mean = amean;
		pm_keptarea = amean * k;
		srt = Array.copy(ina);
		Array.sort(srt);
		mid = floor(k / 2);
		if (k % 2 == 1) {
			pm_median = srt[mid];
		} else {
			pm_median = (srt[mid - 1] + srt[mid]) / 2;
		}
		p95i = round(0.95 * (k - 1));
		pm_p95 = srt[p95i];
		Array.getStatistics(ins, smin, smax, smean, ssd);
		pm_solid = smean;
		Array.getStatistics(inc, cmin, cmax, cmean, csd);
		pm_circ = cmean;
	}
}

function count_particles() {
	run("Select None");
	setThreshold(255, 255);
	run("Analyze Particles...", "size=0-Infinity pixel summarize");
	resetThreshold();
	pm_pre = Table.get("Count", Table.size("Summary") - 1, "Summary");
	close("Summary");
}

// split touching cells in the active binary image "work" (white objects on black)
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

function skeleton_pixels() {
	run("Select None");
	run("Duplicate...", "title=skel_tmp");
	run("Skeletonize (2D/3D)");
	run("Select None");
	getRawStatistics(npx, mn);
	v = mn / 255 * npx;
	close("skel_tmp");
	return v;
}

function overlap_metrics(path) {
	m_dice = "NA";
	m_iou = "NA";
	m_prec = "NA";
	m_rec = "NA";
	if (path == "") {
		return;
	}
	selectImage("work");
	getDimensions(w, h, c, s, f);
	open(path);
	rtitle = getTitle();
	getDimensions(w2, h2, c2, s2, f2);
	if (crop_size > 0 && w2 > crop_size && h2 > crop_size) {
		makeRectangle(round((w2 - crop_size) / 2), round((h2 - crop_size) / 2), crop_size, crop_size);
		run("Crop");
		getDimensions(w2, h2, c2, s2, f2);
	}
	if (w2 != w || h2 != h) {
		print("   mask size differs from image, skipped: " + path);
		close(rtitle);
		selectImage("work");
		return;
	}
	run("8-bit");
	fix_lut();
	run("Select None");
	setThreshold(128, 255);
	run("Convert to Mask");
	getRawStatistics(npx, mn);
	if (mn > 127.5) {
		run("Invert");
	}
	rename("ref_tmp");
	imageCalculator("AND create", "work", "ref_tmp");
	ititle = getTitle();
	getRawStatistics(npx, mi);
	inter = mi / 255 * npx;
	close(ititle);
	selectImage("work");
	getRawStatistics(npx, mw);
	pred = mw / 255 * npx;
	selectImage("ref_tmp");
	getRawStatistics(npx, mr);
	refpx = mr / 255 * npx;
	close("ref_tmp");
	selectImage("work");
	if (pred + refpx > 0) {
		m_dice = 2 * inter / (pred + refpx);
	}
	if (pred + refpx - inter > 0) {
		m_iou = inter / (pred + refpx - inter);
	}
	if (pred > 0) {
		m_prec = inter / pred;
	}
	if (refpx > 0) {
		m_rec = inter / refpx;
	}
}


// ---------------------------------------------------------------------------
// PER IMAGE
// ---------------------------------------------------------------------------
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

function open_base(path) {
	open(path);
	ensure_scale(File.getName(path));
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
	getDimensions(w, h, c, s, f);
	if (crop_size > 0 && w > crop_size && h > crop_size) {
		makeRectangle(round((w - crop_size) / 2), round((h - crop_size) / 2), crop_size, crop_size);
		run("Crop");
	}
	rename("base_img");
}

function process_image(path, idx, total) {
	stem = File.getNameWithoutExtension(path);
	stamp("Image " + (idx + 1) + "/" + total + ": " + stem);
	open_base(path);
	getDimensions(w, h, c, s, f);
	getPixelSize(unit, pw, ph);
	cached_pp = "";
	cached_base = "";
	sigma_scale = 1;
	radius_scale = 1;
	last_pw = pw;
	last_unit = unit;
	if (unit != "pixels" && unit != "pixel" && unit != "") {
		sigma_scale = 1 / pw;
		radius_scale = benchPixel / pw;
	}
	clear_tube_cache();
	// area filter in pixels (calibrated units are converted with the pixel size)
	div = 1;
	if (area_units_cal && unit != "pixels" && unit != "pixel" && unit != "") {
		div = pw * ph;
	}
	nflt = flt_val.length;
	flt_px = newArray(nflt);
	split_min_px = 1000000000000;
	for (q = 0; q < nflt; q++) {
		flt_px[q] = flt_val[q] / div;
		split_min_px = minOf(split_min_px, flt_px[q]);
	}
	area_lo = flt_px[0];
	area_hi = max_eff;
	if (max_area > 0) {
		area_hi = max_area / div;
	}
	for (q = 0; q < nflt; q++) {
		print("   minimum area filter " + flt_val[q] + " = " + d2s(flt_px[q], 1) + " px^2 (maximum " + d2s(area_hi, 1) + " px^2)");
	}
	if (do_review) {
		File.makeDirectory(out_dir + "ReviewPanels/");
		rev_root = out_dir + "ReviewPanels/" + stem + "/";
		File.makeDirectory(rev_root);
		for (fi = 0; fi < nflt; fi++) {
			rev_dir = rev_root + flt_tag[fi] + "/";
			File.makeDirectory(rev_dir);
			old = getFileList(rev_dir);
			for (q = 0; q < old.length; q++) {
				File.delete(rev_dir + old[q]);
			}
			make_original_panel();
		}
	}
	gt_path = "";
	ref_path = "";
	if (use_gt) {
		gt_path = find_mask(gt_dir, stem + gt_suffix);
		if (gt_path == "") {
			print("   no ground truth mask found for " + stem);
		}
	}
	if (use_ref) {
		ref_path = find_mask(ref_dir, stem + "_thresholded");
		if (ref_path == "") {
			print("   no Program 2 thresholded image found for " + stem);
		}
	}

	for (a = 0; a < arm_name.length; a++) {
		showStatus("Image " + (idx + 1) + "/" + total + ": " + arm_name[a]);
		armstart = getTime();
		stamp("  arm " + (a + 1) + "/" + arm_name.length + ": " + arm_name[a]);
		reuse_mask = false;
		if (arm_base[a] == cached_base) {
			if (isOpen("mask_cache")) {
				reuse_mask = true;
			}
		}
		istube = (arm_pp[a] == "Tubeness");
		if (reuse_mask) {
			selectImage("mask_cache");
			run("Duplicate...", "title=work");
			stamp("      reusing the mask of " + arm_base[a] + " (timings below are its original cost)");
		} else {
			tm_pp = "NA";
			tm_soma = "NA";
			tm_tub = "NA";
			tm_gate = "NA";
			tm_thr = "NA";
			tm_close = "NA";
			tm_post = "NA";
			tm_sigma_str = "NA";
			tm_cached = false;

			// source image: raw for Tubeness, otherwise the cached preprocessed image
			src = "base_img";
			if (!istube) {
				if (arm_pp[a] != cached_pp) {
					if (isOpen("pp_img")) {
						close("pp_img");
					}
					selectImage("base_img");
					run("Duplicate...", "title=pp_img");
					tp = getTime();
					apply_pp(arm_pp[a]);
					tm_pp_cache = getTime() - tp;
					cached_pp = arm_pp[a];
					stamp("      preprocessing " + arm_pp[a] + ": " + sec(tm_pp_cache));
				}
				tm_pp = tm_pp_cache;
				src = "pp_img";
			}
			selectImage(src);
			run("Duplicate...", "title=work");

			if (istube) {
				tube_cutoff = arm_cut[a];
				tubeness_segment(arm_tv[a]);
			} else {
				t1 = getTime();
				apply_threshold(arm_type[a], arm_method[a], arm_radius[a]);
				tm_thr = getTime() - t1;
				stamp("      threshold: " + sec(tm_thr));
			}
			ensure_binary();
			// note: || and && do not short-circuit in the macro language, so look up tv_post only for Tubeness arms
			dopost = true;
			if (istube) {
				dopost = (tv_post[arm_tv[a]] == 1);
			}
			if (dopost) {
				t1 = getTime();
				postprocess();
				tm_post = getTime() - t1;
				stamp("      post-processing: " + sec(tm_post));
			}
			normalize_binary();
			run("Set Scale...", "distance=0 known=0 unit=pixel");
			if (isOpen("mask_cache")) {
				close("mask_cache");
			}
			run("Duplicate...", "title=mask_cache");
			cached_base = arm_base[a];
			selectImage("work");
		}

		// splitting touching cells
		pm_pre = "NA";
		split_multi = "NA";
		tm_split = "NA";
		has_cut = false;
		if (isOpen("split_pre")) {
			close("split_pre");
		}
		if (arm_split[a] > 0) {
			selectImage("work");
			count_particles();
			run("Duplicate...", "title=split_pre");
			selectImage("work");
			split_sigma_px = arm_sig[a] * sigma_scale;
			split_prom = arm_prom[a];
			ts = getTime();
			split_cells(arm_split[a]);
			tm_split = getTime() - ts;
			has_cut = true;
			stamp("      split (" + arm_split[a] + "): " + sec(tm_split) + ", " + pm_pre + " particles before, " + split_multi + " multi-seed particles cut");
		}
		selectImage("work");

		getRawStatistics(npx, mn);
		fg_px = mn / 255 * npx;
		skel = "NA";
		skel_ratio = "NA";
		firstrow = Table.size("Benchmark");
		for (fi = 0; fi < nflt; fi++) {
			tmet = getTime();
			area_lo = flt_px[fi];
			flt_label = "min " + flt_val[fi];
			selectImage("work");
			particle_metrics();
			selectImage("work");
			gt_count();
			selectImage("work");
			if (fi == 0) {
				if (do_skeleton && !pm_skipped) {
					skel = skeleton_pixels();
					selectImage("work");
					if (fg_px > 0) {
						skel_ratio = skel / fg_px;
					}
				}
				overlap_metrics(gt_path);
				g_dice = m_dice;
				g_iou = m_iou;
				g_prec = m_prec;
				g_rec = m_rec;
				overlap_metrics(ref_path);
				selectImage("work");
			}
			tm_metrics = getTime() - tmet;

			pc = "NA";
			pu = "NA";
			pd = "NA";
			if (!istube) {
				pc = substring(arm_pp[a], 1, 2);
				pu = substring(arm_pp[a], 3, 4);
				pd = substring(arm_pp[a], 5, 6);
			}
			tubesig = "NA";
			if (istube) {
				tubesig = tv_sigmas[arm_tv[a]];
			}

			row = Table.size("Benchmark");
			tset("Image", row, stem);
			tset("Arm", row, arm_name[a]);
			tset("Preprocess", row, arm_pp[a]);
			tset("PP_contrast", row, pc);
			tset("PP_unsharp", row, pu);
			tset("PP_despeckle", row, pd);
			tset("ThresholdType", row, arm_type[a]);
			tset("Method", row, arm_method[a]);
			tset("Radius", row, arm_radius[a]);
			tset("Tubeness_sigmas", row, tubesig);
			tset("Pixel_size", row, pw);
			tset("Pixel_unit", row, unit);
			tset("Min_area", row, flt_val[fi]);
			tset("Area_lo_px", row, area_lo);
			tset("Area_hi_px", row, area_hi);
			tset("FG_fraction", row, fg_px / npx);
			tset("N_particles", row, pm_n);
			tset("N_in_filter", row, pm_nin);
			tset("N_below_min", row, pm_nsmall);
			tset("N_above_max", row, pm_nbig);
			tset("Mean_area_px", row, pm_mean);
			tset("Median_area_px", row, pm_median);
			tset("Mean_solidity", row, pm_solid);
			tset("Mean_circularity", row, pm_circ);
			tset("Skeleton_px", row, skel);
			tset("Skeleton_per_FG_px", row, skel_ratio);
			tset("FG_intensity_ratio", row, fg_ratio);
			tset("Detail_skipped", row, pm_skipped);
			tset("Binarised_fix", row, fixed_binary);
			tset("Dice_GT", row, g_dice);
			tset("IoU_GT", row, g_iou);
			tset("Precision_GT", row, g_prec);
			tset("Recall_GT", row, g_rec);
			tset("Dice_P2thresholded", row, m_dice);
			tset("IoU_P2thresholded", row, m_iou);
			tset("T_preprocess_ms", row, tm_pp);
			tset("T_soma_ms", row, tm_soma);
			tset("T_tubeness_ms", row, tm_tub);
			tset("T_gate_ms", row, tm_gate);
			tset("T_threshold_ms", row, tm_thr);
			tset("T_closing_ms", row, tm_close);
			tset("T_post_ms", row, tm_post);
			splitname = "none";
			if (arm_split[a] == 1) {
				splitname = "soma";
			}
			kf = "NA";
			if (pm_keptarea >= 0 && fg_px > 0) {
				kf = pm_keptarea / fg_px;
			}
			lp = "NA";
			if (pm_largest >= 0) {
				lp = pm_largest;
			}
			p95 = "NA";
			if (pm_p95 >= 0) {
				p95 = pm_p95;
			}
			tset("Base_arm", row, arm_base[a]);
			tset("Split_mode", row, splitname);
			sg = "NA";
			pr = "NA";
			if (arm_split[a] == 1) {
				sg = arm_sig[a];
				pr = arm_prom[a];
			}
			tset("Seed_sigma_um", row, sg);
			tset("Seed_prominence", row, pr);
			tc2 = "NA";
			if (istube) {
				tc2 = arm_cut[a];
			}
			ec2 = "NA";
			if (istube) {
				tc2 = arm_cut[a];
				if (tc2 < 0) {
					tc2 = "k" + (-tc2);
				} else {
					tc2 = "c" + tc2;
				}
				ec2 = String.trim(eff_cut_str);
			}
			tset("Tube_cutoff", row, tc2);
			tset("Tube_effective_cut", row, ec2);
			tset("N_pre_split", row, pm_pre);
			tset("N_multi_seed", row, split_multi);
			tset("T_split_ms", row, tm_split);
			tset("Kept_area_fraction", row, kf);
			tset("Largest_particle_px", row, lp);
			tset("Area_P95_px", row, p95);
			tset("Mask_reused", row, reuse_mask);
			tset("T_metrics_ms", row, tm_metrics);
			tset("Sigma_times_ms", row, tm_sigma_str);
			tset("Tubeness_reused", row, tm_cached);
			tset("Cells_marked", row, mark_n);
			tset("Cells_recovered_alone", row, gc_single);
			tset("Cells_in_merged_particles", row, gc_in_merged);
			tset("Merged_particles", row, gc_merged_parts);
			tset("Cells_missed", row, gc_missed);
			tset("Non_cell_particles", row, gc_noncell);

			if (do_review) {
				trv = getTime();
				rev_dir = rev_root + flt_tag[fi] + "/";
				make_review_panel(a, stem, fg_px / npx);
				tset("T_review_ms", row, getTime() - trv);
			}
		}
		if (isOpen("split_pre")) {
			close("split_pre");
		}
		selectImage("work");
		if (save_masks) {
			saveAs("Tiff", mask_root + arm_name[a] + "/" + stem + ".tif");
			close();
		} else {
			close("work");
		}
		for (rr = firstrow; rr < Table.size("Benchmark"); rr++) {
			tset("T_total_ms", rr, getTime() - armstart);
		}
		Table.save(out_dir + "PreprocessBenchmark_Results.csv", "Benchmark");
		run("Collect Garbage");
		stamp("      arm finished in " + sec(getTime() - armstart));
	}
	if (isOpen("pp_img")) {
		close("pp_img");
	}
	if (isOpen("mask_cache")) {
		close("mask_cache");
	}
	close("base_img");
	clear_tube_cache();
	if (do_review) {
		for (fi = 0; fi < nflt; fi++) {
			rev_dir = rev_root + flt_tag[fi] + "/";
			build_montage(stem, flt_tag[fi]);
		}
		if (do_combined && flt_tag.length > 1) {
			build_combined_montage(stem);
		}
	}
}


// ---------------------------------------------------------------------------
// SETUP
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// COLOUR-CODED REVIEW PANELS (nothing is removed from the masks)
//   white  = particle inside the area filter (would be kept)
//   red    = at or below the minimum area (would be removed)
//   cyan   = at or above the maximum area (would be removed)
//   yellow = split line (touching cells cut here)
// Particles are classified on the whole image, then the central review_crop region
// is cropped, scaled to panel_px, labelled and saved. One montage is built per image.
// ---------------------------------------------------------------------------
function legend_item(x, y, r, g, b, txt) {
	setColor(r, g, b);
	fillRect(x, y - 10, 10, 10);
	setColor(255, 255, 255);
	drawString(txt, x + 14, y);
	return x + 14 + getStringWidth(txt) + 14;
}

function label_panel(name, fgfrac) {
	w = getWidth();
	setColor(0, 0, 0);
	fillRect(0, 0, w, 58);
	setFont("SansSerif", 15, "bold antialiased");
	setColor(255, 255, 255);
	drawString(name, 6, 17);
	nx = 6 + getStringWidth(name) + 14;
	setFont("SansSerif", 12, "bold antialiased");
	setColor(255, 255, 255);
	drawString(flt_label, nx, 17);
	setFont("SansSerif", 12, "antialiased");
	kt = "kept " + pm_nin;
	st = "<min " + pm_nsmall;
	bt = ">max " + pm_nbig;
	showmax = (area_hi < 100000000000);
	if (pm_skipped) {
		kt = "kept n/a";
		st = "<min n/a";
		bt = ">max n/a";
	}
	x = 6;
	y = 37;
	x = legend_item(x, y, 255, 255, 255, kt);
	x = legend_item(x, y, 255, 0, 0, st);
	if (showmax) {
		x = legend_item(x, y, 0, 255, 255, bt);
	}
	fgtxt = "fg " + d2s(100 * fgfrac, 1) + "%";
	drawString(fgtxt, x, y);
	x = x + getStringWidth(fgtxt) + 14;
	if (has_cut) {
		x = legend_item(x, y, 255, 255, 0, "cuts: " + pm_pre + ">" + pm_n);
	}
	if (mark_n > 0) {
		setColor(255, 255, 0);
		drawString("cells alone " + gc_single + "/" + mark_n + "  merged " + gc_in_merged + "  missed " + gc_missed + "  NON-CELL " + gc_noncell, 6, 54);
	}
}

function make_review_panel(a, stem, fgfrac) {
	selectImage("work");
	run("Select None");
	// particles at or below the minimum area
	if (area_lo > 0) {
		setThreshold(255, 255);
		run("Analyze Particles...", "size=0-" + area_lo + " pixel show=Masks");
		resetThreshold();
		rename("rv_small");
	} else {
		run("Duplicate...", "title=rv_small");
		run("Multiply...", "value=0");
	}
	fix_lut();
	// particles at or above the maximum area
	selectImage("work");
	if (area_hi < 100000000000) {
		setThreshold(255, 255);
		run("Analyze Particles...", "size=" + area_hi + "-Infinity pixel show=Masks");
		resetThreshold();
		rename("rv_big");
	} else {
		run("Duplicate...", "title=rv_big");
		run("Multiply...", "value=0");
	}
	fix_lut();
	// channels: R = every particle, G = kept + too big, B = kept
	// R = everything except too-big particles, G and B = everything except too-small ones
	// white = kept, red = too small, cyan = too big, yellow = split line
	imageCalculator("Subtract create", "work", "rv_big");
	rename("rv_R");
	imageCalculator("Subtract create", "work", "rv_small");
	rename("rv_G");
	run("Duplicate...", "title=rv_B");
	if (has_cut) {
		imageCalculator("Subtract create", "split_pre", "work");
		rename("rv_cut");
		run("Maximum...", "radius=2");
		imageCalculator("Add", "rv_R", "rv_cut");
		imageCalculator("Add", "rv_G", "rv_cut");
		imageCalculator("Subtract", "rv_B", "rv_cut");
		close("rv_cut");
	}
	selectImage("work");
	close("rv_small");
	close("rv_big");
	run("Merge Channels...", "c1=rv_R c2=rv_G c3=rv_B");
	rename("rv_rgb");

	getDimensions(rw, rh, rc, rs, rf);
	if (reg_w > 0) {
		makeRectangle(reg_x, reg_y, reg_w, reg_h);
		run("Crop");
	} else if (review_crop > 0 && (rw > review_crop || rh > review_crop)) {
		cw = minOf(review_crop, rw);
		chh = minOf(review_crop, rh);
		makeRectangle(round((rw - cw) / 2), round((rh - chh) / 2), cw, chh);
		run("Crop");
	}
	getDimensions(cw2, ch2, rc, rs, rf);
	sc = panel_px / maxOf(cw2, ch2);
	pw2 = round(cw2 * sc);
	ph2 = round(ch2 * sc);
	run("Scale...", "x=- y=- width=" + pw2 + " height=" + ph2 + " interpolation=Bilinear average create title=rv_panel");
	close("rv_rgb");
	selectImage("rv_panel");
	label_panel(arm_name[a], fgfrac);
	saveAs("PNG", rev_dir + IJ.pad(a + 1, 3) + "_" + arm_name[a] + ".png");
	close();
	selectImage("work");
}

// Raw 8-bit image, same central region and panel size as the arm panels (saved as 000_Original so it is the first tile)
function make_original_panel() {
	selectImage("base_img");
	run("Select None");
	run("Duplicate...", "title=rv_orig");
	getDimensions(rw, rh, rc, rs, rf);
	if (reg_w > 0) {
		makeRectangle(reg_x, reg_y, reg_w, reg_h);
		run("Crop");
	} else if (review_crop > 0 && (rw > review_crop || rh > review_crop)) {
		cw = minOf(review_crop, rw);
		chh = minOf(review_crop, rh);
		makeRectangle(round((rw - cw) / 2), round((rh - chh) / 2), cw, chh);
		run("Crop");
	}
	getDimensions(cw2, ch2, rc, rs, rf);
	sc = panel_px / maxOf(cw2, ch2);
	pw2 = round(cw2 * sc);
	ph2 = round(ch2 * sc);
	run("Scale...", "x=- y=- width=" + pw2 + " height=" + ph2 + " interpolation=Bilinear average create title=rv_orig_panel");
	close("rv_orig");
	selectImage("rv_orig_panel");
	run("RGB Color");
	w = getWidth();
	setColor(0, 0, 0);
	fillRect(0, 0, w, 44);
	setFont("SansSerif", 15, "bold antialiased");
	setColor(255, 255, 255);
	drawString("Original (raw 8-bit, same region)", 6, 17);
	setFont("SansSerif", 12, "antialiased");
	drawString("no threshold, no area filter", 6, 37);
	saveAs("PNG", rev_dir + "000_Original.png");
	close();
	selectImage("base_img");
}

// One montage per image with every arm and every minimum-area filter: rows = arms, columns = filters.
function build_combined_montage(stem) {
	nf = flt_tag.length;
	cdir = out_dir + "CombinedPanels/";
	File.makeDirectory(cdir);
	cdir = cdir + stem + "/";
	File.makeDirectory(cdir);
	old = getFileList(cdir);
	for (q = 0; q < old.length; q++) {
		File.delete(cdir + old[q]);
	}
	for (fj = 0; fj < nf; fj++) {
		sdir = rev_root + flt_tag[fj] + "/";
		lst = getFileList(sdir);
		for (q = 0; q < lst.length; q++) {
			nm = lst[q];
			if (endsWith(nm, ".png")) {
				pre = substring(nm, 0, 3);
				rest = substring(nm, 4, lengthOf(nm));
				File.copy(sdir + nm, cdir + pre + "_" + fj + "_" + rest);
			}
		}
	}
	run("Image Sequence...", "open=[" + cdir + "] file=.png sort");
	stk = getTitle();
	n = nSlices;
	rows = floor((n + nf - 1) / nf);
	run("Make Montage...", "columns=" + nf + " rows=" + rows + " scale=" + comb_scale + " border=4");
	saveAs("PNG", out_dir + "ReviewMontage_" + stem + "_ALL.png");
	close();
	selectImage(stk);
	close();
	old = getFileList(cdir);
	for (q = 0; q < old.length; q++) {
		File.delete(cdir + old[q]);
	}
	stamp("Combined montage saved: " + out_dir + "ReviewMontage_" + stem + "_ALL.png (rows = arms, columns = minimum area filters)");
}

function build_montage(stem, tag) {
	list = getFileList(rev_dir);
	if (list.length == 0) {
		return;
	}
	run("Image Sequence...", "open=[" + rev_dir + "] file=.png sort");
	stk = getTitle();
	n = nSlices;
	rows = floor((n + montage_cols - 1) / montage_cols);
	run("Make Montage...", "columns=" + montage_cols + " rows=" + rows + " scale=1 border=4");
	saveAs("PNG", out_dir + "ReviewMontage_" + stem + "_" + tag + ".png");
	close();
	selectImage(stk);
	close();
	stamp("Review montage saved: " + out_dir + "ReviewMontage_" + stem + "_" + tag + ".png");
}

// ---------------------------------------------------------------------------
// v11: PRESETS AND DIALOG
// ---------------------------------------------------------------------------
// preselect the dropdown from the last row written by the Image Quality Check macro (read BEFORE anything clears the Results table)
function detect_preset() {
	pick = 6;
	qc_note = "No Image Quality Check result found; choose the image type yourself.";
	if (isOpen("Results")) {
		if (nResults > 0) {
			hd = Table.headings("Results");
			if (indexOf(hd, "Background_class") >= 0 && indexOf(hd, "SNR_class") >= 0) {
				bgc = toUpperCase(getResultString("Background_class", nResults - 1));
				snc = toUpperCase(getResultString("SNR_class", nResults - 1));
				lvl = -1;
				if (indexOf(bgc, "LOW") >= 0) {
					lvl = 0;
				}
				if (indexOf(bgc, "MEDIUM") >= 0) {
					lvl = 1;
				}
				if (indexOf(bgc, "HIGH") >= 0) {
					lvl = 2;
				}
				if (lvl >= 0) {
					off = 1;
					if (indexOf(snc, "HIGH") >= 0) {
						off = 0;
					}
					pick = 2 * lvl + off;
					qc_note = "Preselected from the last Image Quality Check result: " + bgc + ", " + snc + " (intermediate SNR is treated as low).";
				}
			}
		}
	}
	return pick;
}

function get_parameters() {
	rec_text[0] = "Low background, high SNR: Tubeness (cutoff 20 was best in the benchmark) vs local and global thresholds.";
	rec_text[1] = "Low background, low SNR: Tubeness lost its advantage at low SNR; local thresholds (Mean, Niblack) with unsharp mask degrade most gradually.";
	rec_text[2] = "Medium background, high SNR: Huang gave scores near Niblack with about half the non-cell particles; Niblack and Mean recover more cells but keep many non-cell particles.";
	rec_text[3] = "Medium background, low SNR: local thresholds with unsharp mask; compare how many non-cell particles each keeps.";
	rec_text[4] = "High background, high SNR: all methods lose cells in the benchmark; Phansalkar keeps the fewest non-cell particles. Use a larger area filter and check by eye.";
	rec_text[5] = "High background, low SNR: the hardest case; expect missed cells and non-cell particles. Compare Phansalkar and Niblack with large area filters.";
	rec_text[6] = "Broad comparison: the benchmark shortlist (Huang, Niblack, Mean, Phansalkar, Li) and Tubeness (TubeOrig at cutoffs 15, 20, 25 and noise-relative k5; Tube3Post at 20 and 25). Tubeness arms are slow on large images; use the quick-test crop if needed.";
	preset_idx = detect_preset();

	Dialog.create("Settings test on one image (v11)");
	Dialog.addMessage("The image that is open now is the test image (if none is open, you will be asked for a file).\nRun the Image Quality Check macro first.");
	Dialog.addMessage(qc_note);
	Dialog.addChoice("My image has", preset_names, preset_names[preset_idx]);
	Dialog.addChoice("Splitting touching cells", newArray("Compare both: no split and soma-seeded split (recommended)", "Soma-seeded split only", "No splitting only"), "Compare both: no split and soma-seeded split (recommended)");
	Dialog.addCheckbox("Also compare seed settings for the lead option (sigma 3 vs 2 um, prominence 8 vs 12)", false);
	Dialog.addCheckbox("Mark the cells in the panel region first, so the table counts cells and non-cell particles (recommended)", true);
	Dialog.addString("Minimum area filter(s) in um^2, comma separated (blank = preset)", "", 20);
	Dialog.addNumber("Microglia channel", 1);
	Dialog.addNumber("Test box (panels and cell marking): starting size N x N pixels, centred (0 = whole image); you can move it", 800);
	Dialog.addNumber("Panel size in pixels", 500);
	Dialog.addNumber("Montage columns (per-filter montages)", 4);
	Dialog.addNumber("Quick test: process only the central N x N pixels (0 = whole image)", 0);
	Dialog.show();
	choice = Dialog.getChoice();
	splitchoice = Dialog.getChoice();
	seed_sweep = Dialog.getCheckbox();
	do_mark = Dialog.getCheckbox();
	flt_in = String.trim(Dialog.getString());
	channel = Dialog.getNumber();
	review_crop = Dialog.getNumber();
	panel_px = Dialog.getNumber();
	montage_cols = Dialog.getNumber();
	crop_size = Dialog.getNumber();
	for (q = 0; q < preset_names.length; q++) {
		if (preset_names[q] == choice) {
			preset_idx = q;
		}
	}

	// area filters: lower bound only, in um^2
	min_list = "50,100";
	if (preset_idx == 2 || preset_idx == 3) {
		min_list = "100,130";
	}
	if (preset_idx == 4 || preset_idx == 5) {
		min_list = "100,130,150";
	}
	if (preset_idx == 6) {
		min_list = "50,100,130";
	}
	if (flt_in != "") {
		min_list = flt_in;
	}

	// splitting
	split_on = newArray(1, 1);
	if (startsWith(splitchoice, "Soma-seeded")) {
		split_on = newArray(0, 1);
	}
	if (startsWith(splitchoice, "No splitting")) {
		split_on = newArray(1, 0);
	}
	sig_list = "3";
	prom_list = "8";
	sweep_only = "";
	if (seed_sweep) {
		sig_list = "3,2";
		prom_list = "8,12";
		sweep_only = lead_pat[preset_idx];
	}

	// fixed settings of the engine
	expA = false;
	expB = true;
	expC = false;
	soma_sd = 2;
	us_radius = 3;
	us_weight = 0.6;
	max_area = 0;
	max_eff = 1000000000000;
	area_units_cal = true;
	do_review = true;
	do_combined = true;
	comb_scale = 0.5;
	do_skeleton = false;
	save_masks = true;
	use_gt = false;
	use_ref = false;
	reuse_tube = true;
	run_short = true;
	run_mode = 0;
}

function add_tube_arms(cutlist) {
	add_tube_variant(0, cutlist);
}

// v = 0 TubeOrig (5 sigmas), 2 Tube3Post (3 sigmas + Program 2 post-processing); a "k" entry such as k5 is a noise-relative cutoff
function add_tube_variant(v, cutlist) {
	tube_cut_list = cutlist;
	parse_cut_list();
	for (ci2 = 0; ci2 < tube_cuts.length; ci2++) {
		cur_cut = tube_cuts[ci2];
		add_arm("Tubeness", "tubeness", tv_name[v], tv_radius[v], v);
	}
	cur_cut = 0;
}

// C0U1D1 = Program 2 standard preprocessing; C0U0D0 = none; C1U0D0 = contrast stretch only
function build_arms() {
	p2 = "C0U1D1";
	nopp = "C0U0D0";
	tube_cut_list = "20";
	parse_cut_list();
	if (preset_idx == 0) {
		add_tube_arms("15,20,25");
		add_arm(p2, "auto", "Huang", 0, -1);
		add_arm(nopp, "auto", "Huang", 0, -1);
		add_arm(p2, "local", "Mean", 100, -1);
		add_arm(nopp, "local", "Mean", 100, -1);
		add_arm(p2, "local", "Niblack", 100, -1);
	}
	if (preset_idx == 1) {
		add_arm(p2, "local", "Mean", 100, -1);
		add_arm(nopp, "local", "Mean", 100, -1);
		add_arm(p2, "local", "Niblack", 100, -1);
		add_arm(p2, "auto", "Huang", 0, -1);
		add_arm(nopp, "auto", "Huang", 0, -1);
		add_arm(p2, "local", "Phansalkar", 100, -1);
		add_tube_arms("20,30");
	}
	if (preset_idx == 2) {
		add_arm(p2, "auto", "Huang", 0, -1);
		add_arm(nopp, "auto", "Huang", 0, -1);
		add_arm(p2, "local", "Niblack", 100, -1);
		add_arm(nopp, "local", "Niblack", 100, -1);
		add_arm(p2, "local", "Mean", 100, -1);
		add_arm(p2, "local", "Phansalkar", 100, -1);
		add_tube_arms("25,30");
	}
	if (preset_idx == 3) {
		add_arm(p2, "local", "Niblack", 100, -1);
		add_arm(nopp, "local", "Niblack", 100, -1);
		add_arm(p2, "local", "Mean", 100, -1);
		add_arm(p2, "auto", "Huang", 0, -1);
		add_arm(p2, "local", "Phansalkar", 100, -1);
	}
	if (preset_idx == 4) {
		add_arm(p2, "local", "Phansalkar", 100, -1);
		add_arm(nopp, "local", "Phansalkar", 100, -1);
		add_arm(p2, "local", "Niblack", 100, -1);
		add_arm(p2, "auto", "Huang", 0, -1);
		add_arm(nopp, "auto", "Huang", 0, -1);
		add_tube_arms("25,30");
	}
	if (preset_idx == 5) {
		add_arm(p2, "local", "Phansalkar", 100, -1);
		add_arm(nopp, "local", "Phansalkar", 100, -1);
		add_arm(p2, "local", "Niblack", 100, -1);
		add_arm(p2, "auto", "Huang", 0, -1);
		add_arm(p2, "local", "Mean", 100, -1);
	}
	if (preset_idx == 6) {
		add_arm(p2, "local", "Niblack", 100, -1);
		add_arm(p2, "auto", "Huang", 0, -1);
		add_arm(nopp, "auto", "Huang", 0, -1);
		add_arm(p2, "local", "Mean", 100, -1);
		add_arm(p2, "local", "Phansalkar", 100, -1);
		add_arm("C1U0D0", "auto", "Li", 0, -1);
		add_tube_variant(0, "15,20,25,k5");
		add_tube_variant(2, "20,25");
	}
}

// ---------------------------------------------------------------------------
// v11: KEY FILE (tile number -> settings)
// ---------------------------------------------------------------------------
function pp_words(pp) {
	w = "";
	if (substring(pp, 1, 2) == "1") {
		w = w + "contrast stretch (saturated 0.35%, normalize); ";
	}
	if (substring(pp, 3, 4) == "1") {
		w = w + "Unsharp Mask (radius " + us_radius + ", weight " + us_weight + "); ";
	}
	if (substring(pp, 5, 6) == "1") {
		w = w + "Despeckle; ";
	}
	if (w == "") {
		w = "no preprocessing; ";
	}
	return w;
}

function describe_arm(q) {
	s = "";
	if (arm_pp[q] == "Tubeness") {
		tvq = arm_tv[q];
		if (arm_cut[q] < 0) {
			cs = "noise-relative cutoff k=" + (-arm_cut[q]);
		} else {
			cs = "minimum ridge response " + arm_cut[q] + " (0-255 scale)";
		}
		s = "Tubeness on the raw 8-bit image, sigmas " + tv_sigmas[tvq] + " um, " + cs + "; soma layer = mean + " + soma_sd + " SD; Phansalkar local threshold radius " + round(tv_radius[tvq] * radius_scale) + " px; ";
		if (tv_post[tvq] == 1) {
			s = s + "Program 2 post-processing (Despeckle, Close-, Remove Outliers radius 2)";
		} else {
			s = s + "no Program 2 post-processing";
		}
	} else {
		s = "Preprocessing: " + pp_words(arm_pp[q]);
		if (arm_type[q] == "auto") {
			s = s + "global Auto Threshold " + arm_method[q] + " (ignore black, white); ";
		} else {
			s = s + "Auto Local Threshold " + arm_method[q] + ", radius " + round(arm_radius[q] * radius_scale) + " px (" + arm_radius[q] + " px at 0.3447 um/px), parameters 0; ";
		}
		s = s + "then Program 2 post-processing (Despeckle, Close-, Remove Outliers radius 2)";
	}
	if (arm_split[q] == 1) {
		s = s + "; soma-seeded split (Gaussian sigma " + arm_sig[q] + " um, prominence " + arm_prom[q] + ")";
	} else {
		s = s + "; no splitting";
	}
	return "Tile " + (q + 1) + " = " + arm_name[q] + "\n    " + s;
}

function write_key(stem) {
	t = "Settings test key for " + stem + "\n";
	t = t + "Image type chosen: " + preset_names[preset_idx] + "\n" + rec_text[preset_idx] + "\n\n";
	t = t + "Minimum area filters (um^2, lower bound only): " + min_list + "\n";
	t = t + "Pixel size: " + d2s(last_pw, 4) + " " + last_unit + "; local-threshold radii scaled by " + d2s(radius_scale, 3) + "\n";
	t = t + "In every montage, tile 0 is the raw image and tile N is option N below. In the _ALL montage each row is one option and each column one area filter.\n\n";
	for (q = 0; q < arm_name.length; q++) {
		t = t + describe_arm(q) + "\n";
	}
	t = t + "\nThese are starting points from synthetic images; pick the option whose mask looks best on your own cells.\n";
	File.saveString(t, out_dir + "SettingsKey.txt");
}

// ---------------------------------------------------------------------------
// v11: CELL MARKING AND COUNTS (cells vs non-cell particles)
// You click every cell in the panel region. For each option and filter the kept particles are then sorted:
//   recovered alone = particle holds exactly one marked cell;  merged = particle holds 2 or more marked cells;
//   missed = marked cell not inside any kept particle;  non-cell = kept particle (centre inside the region) with no marked cell
// A piece of a cell that was cut by the split also counts as a non-cell particle (fragment).
// ---------------------------------------------------------------------------
function mark_cells() {
	mark_n = 0;
	open_base(test_path);
	getDimensions(w, h, c, s, f);
	reg_w = w;
	reg_h = h;
	if (review_crop > 0 && review_crop < w) {
		reg_w = review_crop;
	}
	if (review_crop > 0 && review_crop < h) {
		reg_h = review_crop;
	}
	reg_x = round((w - reg_w) / 2);
	reg_y = round((h - reg_h) / 2);
	run("Enhance Contrast", "saturated=0.35");
	// step 1: let the user move (and resize) the test box
	makeRectangle(reg_x, reg_y, reg_w, reg_h);
	setTool("rectangle");
	waitForUser("Place the test box", "Move the yellow test box to a representative area of the tissue:\ndrag inside it to move it, drag a handle to resize it.\nThe montage panels and the cell/non-cell counts use this box.\nClick OK when it is placed.");
	if (selectionType() == 0) {
		getSelectionBounds(bx, by, bw, bh);
		reg_x = bx;
		reg_y = by;
		reg_w = bw;
		reg_h = bh;
	}
	run("Select None");
	// step 2: mark the cells inside the box
	makeRectangle(reg_x, reg_y, reg_w, reg_h);
	run("Add Selection...", "stroke=yellow width=2");
	run("Select None");
	setTool("multipoint");
	waitForUser("Mark the cells", "Click on the cell body of EVERY microglia cell inside the yellow box\n(multi-point tool; Alt-click a point to remove it).\nCells you skip will be counted as non-cell particles.\nWhen finished, click OK.");
	if (selectionType() == 10) {
		getSelectionCoordinates(mx, my);
		mark_x = mx;
		mark_y = my;
		mark_n = mx.length;
	}
	run("Select None");
	close("base_img");
	if (mark_n == 0) {
		print("No cells were marked: the table will show particle counts only.");
	} else {
		print(mark_n + " cells marked in the region x=" + reg_x + ", y=" + reg_y + ", " + reg_w + " x " + reg_h + " px.");
	}
}

// uses the current area_lo / area_hi (pixels); image "work" is the active binary mask
function gt_count() {
	gc_single = 0;
	gc_merged_parts = 0;
	gc_in_merged = 0;
	gc_missed = 0;
	gc_noncell = 0;
	if (mark_n == 0) {
		return;
	}
	selectImage("work");
	run("Select None");
	run("Set Measurements...", "area centroid redirect=None decimal=3");
	setThreshold(255, 255);
	hiopt = "Infinity";
	if (area_hi < 100000000000) {
		hiopt = d2s(area_hi - 0.01, 2);
	}
	run("Analyze Particles...", "size=" + d2s(area_lo + 0.01, 2) + "-" + hiopt + " pixel display clear show=[Count Masks]");
	resetThreshold();
	rename("gt_cm");
	np = nResults;
	if (np == 0) {
		gc_missed = mark_n;
		close("gt_cm");
		run("Clear Results");
		selectImage("work");
		return;
	}
	cx = newArray(np);
	cy = newArray(np);
	for (j = 0; j < np; j++) {
		cx[j] = getResult("X", j);
		cy[j] = getResult("Y", j);
	}
	run("Clear Results");
	hits = newArray(np + 1);
	selectImage("gt_cm");
	iw = getWidth();
	ih = getHeight();
	for (q = 0; q < mark_n; q++) {
		px0 = round(mark_x[q]);
		py0 = round(mark_y[q]);
		lab = 0;
		for (rr = 0; rr <= 3; rr++) {
			if (lab == 0) {
				for (dy = -rr; dy <= rr; dy++) {
					for (dx = -rr; dx <= rr; dx++) {
						if (lab == 0 && maxOf(abs(dx), abs(dy)) == rr) {
							xx = px0 + dx;
							yy = py0 + dy;
							if (xx >= 0 && yy >= 0 && xx < iw && yy < ih) {
								v = getPixel(xx, yy);
								if (v > 0) {
									lab = v;
								}
							}
						}
					}
				}
			}
		}
		if (lab > 0 && lab <= np) {
			hits[lab] = hits[lab] + 1;
		} else {
			gc_missed++;
		}
	}
	close("gt_cm");
	for (j = 1; j <= np; j++) {
		hh = hits[j];
		if (hh == 1) {
			gc_single++;
		}
		if (hh >= 2) {
			gc_merged_parts++;
			gc_in_merged = gc_in_merged + hh;
		}
		if (hh == 0) {
			xc = cx[j - 1];
			yc = cy[j - 1];
			if (xc >= reg_x && xc < reg_x + reg_w && yc >= reg_y && yc < reg_y + reg_h) {
				gc_noncell++;
			}
		}
	}
	selectImage("work");
}

// one row per option x filter, with tile number, shown as a table and saved as csv
function build_summary() {
	nrow = Table.size("Benchmark");
	tname = "SettingsSummary";
	Table.create(tname);
	for (r = 0; r < nrow; r++) {
		arm = Table.getString("Arm", r, "Benchmark");
		tile = 0;
		for (q = 0; q < arm_name.length; q++) {
			if (arm_name[q] == arm) {
				tile = q + 1;
			}
		}
		Table.set("Tile", r, tile, tname);
		Table.set("Option", r, arm, tname);
		Table.set("Min_area_um2", r, Table.get("Min_area", r, "Benchmark"), tname);
		if (mark_n > 0) {
			Table.set("Cells_marked", r, mark_n, tname);
			Table.set("Cells_recovered_alone", r, Table.get("Cells_recovered_alone", r, "Benchmark"), tname);
			Table.set("Cells_in_merged_particles", r, Table.get("Cells_in_merged_particles", r, "Benchmark"), tname);
			Table.set("Cells_missed", r, Table.get("Cells_missed", r, "Benchmark"), tname);
			Table.set("Non_cell_particles", r, Table.get("Non_cell_particles", r, "Benchmark"), tname);
		}
		// the whole-image particle counts are shown only when no cells were marked (they stay in the full results csv)
		if (mark_n == 0) {
			Table.set("Particles_before_filter", r, Table.get("N_particles", r, "Benchmark"), tname);
			Table.set("Removed_below_min", r, Table.get("N_below_min", r, "Benchmark"), tname);
			Table.set("Particles_kept_whole_image", r, Table.get("N_in_filter", r, "Benchmark"), tname);
		}
	}
	Table.update(tname);
	Table.save(out_dir + "SettingsTest_Summary.csv", tname);
	print("");
	if (mark_n > 0) {
		print("Counts inside the marked square only. Tile | Option | Min area | Cells marked | Recovered alone | In merged | Missed | Non-cell particles");
	} else {
		print("Tile | Option | Min area | Particles before filter | Removed (too small) | Kept");
	}
	for (r = 0; r < nrow; r++) {
		tl = Table.get("Tile", r, tname);
		op = Table.getString("Option", r, tname);
		ma = Table.get("Min_area_um2", r, tname);
		if (mark_n > 0) {
			print(tl + " | " + op + " | " + ma + " | " + mark_n + " | " + Table.get("Cells_recovered_alone", r, tname) + " | " + Table.get("Cells_in_merged_particles", r, tname) + " | " + Table.get("Cells_missed", r, tname) + " | " + Table.get("Non_cell_particles", r, tname));
		} else {
			print(tl + " | " + op + " | " + ma + " | " + Table.get("Particles_before_filter", r, tname) + " | " + Table.get("Removed_below_min", r, tname) + " | " + Table.get("Particles_kept_whole_image", r, tname));
		}
	}
}

// the image that is open is the test image; otherwise ask for a file
function pick_image() {
	p = "";
	if (nImages > 0) {
		dd = getInfo("image.directory");
		ff = getInfo("image.filename");
		if (dd != "" && ff != "") {
			if (File.exists(dd + ff)) {
				p = dd + ff;
				user_win_title = getTitle();
			}
		}
	}
	if (p == "") {
		p = File.openDialog("Choose the test image (tif, png or jpg)");
	}
	return p;
}


function parse_filters() {
	items = split_list(min_list);
	if (items.length == 0) {
		items = newArray("0");
	}
	flt_val = newArray(items.length);
	flt_tag = newArray(items.length);
	unitname = "px";
	if (area_units_cal) {
		unitname = "um2";
	}
	for (q = 0; q < items.length; q++) {
		it = items[q];
		flt_val[q] = parseFloat(it);
		tg = replace(it, "\\.", "p");
		flt_tag[q] = "min" + tg + unitname;
	}
}

function parse_seed_lists() {
	sg = split_list(sig_list);
	pg = split_list(prom_list);
	if (sg.length == 0) {
		sg = newArray("3");
	}
	if (pg.length == 0) {
		pg = newArray("8");
	}
	sig_vals = newArray(sg.length);
	prom_vals = newArray(pg.length);
	for (q = 0; q < sg.length; q++) {
		sig_vals[q] = parseFloat(sg[q]);
	}
	for (q = 0; q < pg.length; q++) {
		prom_vals[q] = parseFloat(pg[q]);
	}
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

function in_sweep(nm) {
	if (String.trim(sweep_only) == "") {
		return true;
	}
	pats = split_list(sweep_only);
	for (q = 0; q < pats.length; q++) {
		pt = pats[q];
		if (indexOf(nm, pt) >= 0) {
			return true;
		}
	}
	return false;
}

function add_split_arm(full, bp, bt, bm, br, bv, m, bn, sg, pr, bc) {
	arm_name = Array.concat(arm_name, full);
	arm_pp = Array.concat(arm_pp, bp);
	arm_type = Array.concat(arm_type, bt);
	arm_method = Array.concat(arm_method, bm);
	arm_radius = Array.concat(arm_radius, br);
	arm_tv = Array.concat(arm_tv, bv);
	arm_split = Array.concat(arm_split, m);
	arm_base = Array.concat(arm_base, bn);
	arm_sig = Array.concat(arm_sig, sg);
	arm_prom = Array.concat(arm_prom, pr);
	arm_cut = Array.concat(arm_cut, bc);
}

function expand_split() {
	suffix = newArray("", "_splitSoma");
	n = arm_name.length;
	o_name = Array.copy(arm_name);
	o_pp = Array.copy(arm_pp);
	o_type = Array.copy(arm_type);
	o_method = Array.copy(arm_method);
	o_radius = Array.copy(arm_radius);
	o_tv = Array.copy(arm_tv);
	o_cut = Array.copy(arm_cut);
	arm_name = newArray(0);
	arm_pp = newArray(0);
	arm_type = newArray(0);
	arm_method = newArray(0);
	arm_radius = newArray(0);
	arm_tv = newArray(0);
	arm_split = newArray(0);
	arm_base = newArray(0);
	arm_sig = newArray(0);
	arm_prom = newArray(0);
	arm_cut = newArray(0);
	for (q = 0; q < n; q++) {
		bn = o_name[q];
		bp = o_pp[q];
		bt = o_type[q];
		bm = o_method[q];
		br = o_radius[q];
		bv = o_tv[q];
		bc = o_cut[q];
		for (m = 0; m < 2; m++) {
			if (split_on[m] == 1) {
				if (m == 1) {
					ns = 1;
					np = 1;
					if (in_sweep(bn)) {
						ns = sig_vals.length;
						np = prom_vals.length;
					}
					for (si = 0; si < ns; si++) {
						for (pj = 0; pj < np; pj++) {
							sv = sig_vals[si];
							pv = prom_vals[pj];
							full = bn + "_splitSoma";
							if (ns * np > 1) {
								full = full + "_s" + d2s(sv, 1) + "_p" + d2s(pv, 0);
							}
							add_split_arm(full, bp, bt, bm, br, bv, 1, bn, sv, pv, bc);
						}
					}
				} else {
					full = bn + suffix[m];
					add_split_arm(full, bp, bt, bm, br, bv, m, bn, 0, 0, bc);
				}
			}
		}
	}
}

function any_tubeness() {
	for (q = 0; q < arm_pp.length; q++) {
		if (arm_pp[q] == "Tubeness") {
			return true;
		}
	}
	return false;
}

function check_dependencies() {
	List.setCommands;
	req = newArray("Auto Threshold", "Auto Local Threshold");
	if (do_skeleton) {
		req = Array.concat(req, "Skeletonize (2D/3D)");
	}
	if (any_tubeness()) {
		req = Array.concat(req, "Tubeness");
	}
	missing = "";
	for (i = 0; i < req.length; i++) {
		if (List.get(req[i]) == "") {
			missing = missing + "\n - " + req[i];
		}
	}
	morpho_ok = (List.get("Morphological Filters") != "");
	if (missing != "") {
		exit("These commands were not found in Fiji:" + missing + "\nInstall them (Help > Update...) or untick the option that needs them.");
	}
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
// MACRO STARTS HERE
// ---------------------------------------------------------------------------
get_parameters();
parse_filters();
parse_seed_lists();
build_arms();
expand_split();
if (arm_name.length == 0) {
	exit("No options selected.");
}
check_dependencies();
test_path = pick_image();
if (test_path == "") {
	exit("No test image chosen.");
}
test_stem = File.getNameWithoutExtension(test_path);
out_dir = File.getDirectory(test_path) + "SettingsTest_" + test_stem + "/";
File.makeDirectory(out_dir);
if (!File.exists(out_dir)) {
	showMessage("Output folder", "Could not create a folder next to the image. Choose an output folder.");
	out_dir = getDirectory("Choose an OUTPUT folder");
}
mask_root = out_dir + "Masks/";
File.makeDirectory(mask_root);
for (a = 0; a < arm_name.length; a++) {
	File.makeDirectory(mask_root + arm_name[a] + "/");
}

setOption("BlackBackground", true);
run("Set Measurements...", "area shape redirect=None decimal=4");
Table.create("Benchmark");
run_start = getTime();
print("\\Clear");
print(preset_names[preset_idx]);
print(rec_text[preset_idx]);
stamp("Testing " + arm_name.length + " options on " + test_stem + " (area filters " + min_list + " um^2).");
// give the user's own open window a private name so the engine never touches it
if (user_win_title != "") {
	selectImage(user_win_title);
	rename("user_test_image_held");
}
if (do_mark) {
	mark_cells();
}
setBatchMode(true);
process_image(test_path, 0, 1);
setBatchMode(false);
if (user_win_title != "") {
	selectImage("user_test_image_held");
	rename(user_win_title);
}
Table.save(out_dir + "PreprocessBenchmark_Results.csv", "Benchmark");
write_key(test_stem);
build_summary();

shown = out_dir + "ReviewMontage_" + test_stem + "_ALL.png";
if (!File.exists(shown)) {
	shown = out_dir + "ReviewMontage_" + test_stem + "_" + flt_tag[0] + ".png";
}
if (File.exists(shown)) {
	open(shown);
}
stamp("Done. Montage: " + shown);
stamp("Settings of every tile: " + out_dir + "SettingsKey.txt");
showMessage("Settings test finished", "Montage opened and summary table saved (SettingsTest_Summary.csv). Tile numbers match SettingsKey.txt.\nFiles are in:\n" + out_dir);
