# MicrogliaMorphology2

#### *An updated version of the ImageJ macros for microglia morphology analysis*
**Current versions:** TestImageSettingsPicker v13 (AllOptions), Program 2.4, ColorByCluster, CountMicroglia v3.

**Created**: 21 January, 2026 **Last updated**: 5 Nov, 2026


MicrogliaMorphology is a set of ImageJ/Fiji macros that offer a semi-automated approach to characterize 27 morphology features from hundreds to thousands of individual microglia.
This is a modified version of [MicrogliaMorphology](https://github.com/ciernialab/MicrogliaMorphology) with several changes. It is more stable on big datasets that crashed the original pipeline, it can run on multiple regions per image, and it can quantify the intensity of another channel within the microglia. The output measurements are slightly different, so if you want to replicate the original data, please refer to the original GitHub.
The former FracLac analysis had a memory leak that caused problems beyond roughly 20,000 cells. FracLac is no longer used and individual image files are no longer created for every cell, which decreases the file load.

By default the macro produces 27 morphology measures per cell, plus 3 label columns (Label, Image, Region).

Cell shape (9): Area, Perim., Major, Minor, Circ., Feret, MinFeret, Round, Solidity

Convex hull (6): the same measures on the hull: hull_Area, hull_Perim., hull_Major, hull_Minor, hull_Circ., hull_Round. hull_Feret, hull_MinFeret and hull_Solidity are not written because they are redundant

Hull-derived (3): Hull span ratio, Max/min radii from hull, Relative variation (CV) hull

Skeleton (9): # Branches, # Junctions, # End-point voxels, # Junction voxels, # Slab voxels, Average Branch Length, # Triple points, # Quadruple points, Maximum Branch Length


![](./images/microglia_measurements_27features.png)

<details>
<summary>

   ## Citation
</summary>

If you are using this tool, please cite the following publication:

- [Development of a high-throughput pipeline to characterize microglia morphological states at a single-cell resolution](https://www.eneuro.org/content/11/7/ENEURO.0014-24.2024)

> Kim J, Pavlidis P, Ciernia AV. Development of a High-Throughput Pipeline to Characterize Microglia Morphological States at a Single-Cell Resolution. eNeuro. 2024 Jul 30;11(7):ENEURO.0014-24.2024. doi: 10.1523/ENEURO.0014-24.2024. PMID: 39029952; PMCID: PMC11289588.
</details>

---

## Overview: the workflow at a glance

Run the macros in the order below. Each one is found in Fiji under *Plugins > MicrogliaMorphology*. Open the dropdown under each step for the details.

| Step | Macro | What you do | What you get |
| ---- | ----- | ----------- | ------------ |
| 0 | **Install** | Install Fiji and copy the macros into the Fiji plugins folder | Macros appear in the Plugins menu |
| 1 | **TestImageSettingsPicker v13 AllOptions** | Open a test image, place a test box and click every microglia in it | About 93 options tested and ranked, a Top 20 montage and csv, and the settings to use for your dataset |
| 2 | **MicrogliaMorphology Program 2.4** | Pick the Picker's option from a list (or paste its name) and run on the whole dataset | Thresholded masks, split masks and one measurement .csv per image |
| 3 | **Cluster in R** | Run [MicrogliaMorphologyR](https://github.com/ciernialab/MicrogliaMorphologyR) on the measurement files | Morphological clusters and a ColorByCluster label file per image |
| 4 | **CBC (ColorByCluster)** | Point the macro at the original images, final masks and cluster label files | Original images with every microglia colored by its cluster |
| Optional | **CountMicroglia v3** | Run on Iba1 + DAPI images | Microglia counts and densities per region |

**Before you start: give Fiji more memory (RAM).** Fiji's default memory limit is often too low for these macros. Out-of-memory errors, very slow runs or Fiji freezing partway through a batch are the usual signs. Before running any step:

1.  Go to *Edit > Options > Memory & Threads...*
2.  Set **Maximum memory** to about 75% of your computer's RAM (for example about 12000 MB on a 16 GB computer, or 24000 MB on 32 GB). Leave the rest for the operating system.
3.  Click OK and **restart Fiji**. The new limit only takes effect after a restart.
4.  To check it worked, open *Help > About ImageJ* or click the Fiji status bar, which shows the memory in use and the limit.

How much each step needs:

| Step | Memory use | Notes |
| ---- | ---------- | ----- |
| TestImageSettingsPicker | High | Runs about 93 options on one image and keeps a mask for each. Tubeness is the most demanding. If it runs out of memory, use the quick test crop or a smaller test box |
| Program 2.4 | Moderate per image, long runs | Images are processed one at a time, but memory can build up over a large batch. If Fiji slows down or stops, restart it and use the image range option to continue from where it stopped |
| ColorByCluster | Low to moderate | Depends on image size |
| CountMicroglia | Moderate to high | Large multi-channel images and Z-stacks are loaded whole before the max projection |

Close other images and programs before a long run. You can also run *Plugins > Utilities > Collect Garbage* between runs to free memory without restarting Fiji.

**Name your images with metadata.** When generating the single-channel .tiff images that contain the microglia, include the important metadata in the file name, with each descriptor separated by an underscore, for example `CohortName_AnimalID_Condition_Sex_BrainRegion.tiff`. This format is important for compatibility with [MicrogliaMorphologyR](https://github.com/ciernialab/MicrogliaMorphologyR).

**Set the pixel size in microns.** Area filters, local threshold radii and soma seed sizes are all in microns. The macros read the pixel size from the image and ask you to confirm it. If an image has no calibration you will be asked to enter it (*Analyze > Set Scale*).

**16-bit images: use the same conversion setting in the Picker and the Program.** All thresholding is done on an 8-bit copy of the image. Converting a 16-bit image over its full range lets one bright spot or an empty (zero) area squeeze the tissue into a few grey levels. In one example (maximum 9231, mean 346) the tissue ended up in about 10 grey levels and the soma seeds were never found. The default is now a **percentile range**: the 0.5th to 99.8th percentile of the non-zero pixels of the whole image. Choose **Full range** only if you need to reproduce earlier results. Whichever you choose, use the same setting in Step 1 and Step 2. 8-bit images are not affected.

<details>
<summary>

   ## Optional: tracing regions of interest (ROIs)
</summary>

If you are interested in specific regions within your images, trace them in ImageJ before running the Program. [ROIMAPer](https://github.com/ciernialab/ROIMAPer) is one tool that aligns your brain images to the [Allen Brain Institute reference mouse brain atlas](https://mouse.brain-map.org/static/atlas). You can also trace ROIs manually.

- Name the ROIs and save your .tif files so that they include the ROIs.
- In the Program, tick **"Do your images have ROIs traced?"**. Only the part of each image inside the ROIs is then measured.
- TestImageSettingsPicker does not use traced ROIs. It analyzes the test box you place in the whole image.
</details>

---

## Step 0. Installation

**In short:** install Fiji and BioVoxxel Toolbox, copy the macro files into a new `MicrogliaMorphology` folder inside `Fiji.app/scripts/Plugins`, and restart Fiji.

<details>
<summary>

   ### Installation details
</summary>

#### Install Fiji and the required plugins

- [FIJI/ImageJ](https://imagej.net/software/fiji/?Downloads)
- [BioVoxxel Toolbox](https://imagej.net/plugins/biovoxxel-toolbox)

Within Fiji, the Program also uses the Auto Threshold, Auto Local Threshold and Tubeness plugins, and Skeletonize (2D/3D). These are included in a standard Fiji install. MorphoLibJ is optional (the Close- step falls back to a standard method if it is absent). The white top-hat background removal option needs MorphoLibJ.

#### Install the MicrogliaMorphology macros

1.  When you download and install Fiji, the app and its scripts/plugins are saved in a folder called "Fiji.app". Create a new directory called "MicrogliaMorphology" under: Fiji.app > scripts > Plugins.

2.  Save the following files from this repo (macros-scripts folder) into the new MicrogliaMorphology directory:

- **MicrogliaMorphology_TestImageSettingsPicker_v13_AllOptions.ijm**
- **MicrogliaMorphology_Program2.4.ijm**
- **MicrogliaMorphology_ColorByCluster.ijm**
- **MicrogliaMorphology_CountMicroglia_v3.ijm** (optional)

    If you have older versions (for example `CountMicroglia_v1` or an earlier Picker) in the folder, remove them so that only the current versions appear in the menu.

3.  Restart Fiji.

4.  MicrogliaMorphology should now appear under Plugins (at the bottom of the drop-down). Click a macro to start its prompts. Use them in the order listed above.
</details>

---

## Step 1. TestImageSettingsPicker

**In short:** open a representative single-channel test image, run *Plugins > MicrogliaMorphology > MicrogliaMorphology TestImageSettingsPicker v13 AllOptions*, place the test box, click every microglia inside it, and wait (roughly 20 to 30 minutes for a 2000 x 2000 px image). The macro runs about 93 options, counts how many of your marked cells each one recovers whole, and saves a ranked list (`AllOptions_Ranked.csv`), the best 20 (`Top20_Options.csv`) and a montage of those 20 (`Top20_Montage.png`) that starts with your original image. Check the top options by eye and use the best one in Step 2.

<details>
<summary>

   ### TestImageSettingsPicker details
</summary>


#### Procedure

1.  Open a representative test image (if none is open, you are asked for a file).
2.  Run the macro. In the first dialog set:
    - **Splitting touching cells:** compare both no split and soma-seeded split (recommended), soma-seeded split only, or no splitting only.
    - **16-bit images: conversion to 8-bit:** percentile range (recommended) or full range. See *Before you start* above, and use the same choice in the Program.
    - **Compare seed settings** (optional): tests seed blur sigma 3 vs 2 um and prominence 8 vs 12 for the lead option.
    - **Colour every kept particle differently** (recommended): each particle in the panels gets its own colour, so cuts and merged cells are easy to see.
    - **Minimum area filter(s) in um^2:** comma separated (default 50,100). Leave it blank to use 50, 100, 130 and 150.
    - **Microglia channel**, **test box size**, **panel size**, **montage columns**, and an optional **quick test** that processes only the central N x N pixels (shortens the run on large images, since Tubeness is slow).
    - **Pruning check:** the percentage used to decide that a cell is complete (default 60, see below).
    - **Over-growth check:** the percentage above which an option's particles are considered fused cells (default 140, 0 = off, see below).
    - **Minimum recovery:** options that recover fewer than this percentage of your marked cells are not ranked (default 25, 0 = off, see below).

![](./images/picker_dialog_01.png)

3.  Confirm the pixel size when asked. If it is wrong, untick the box and enter the correct pixel width in microns. The value is used for every image in the run and the image file is not changed.

![](./images/Picker_pixelsize.png)

4.  **Place the test box:** drag the yellow box to a representative area of tissue (drag inside it to move, drag a handle to resize) and click OK. The montage panels and the cell/non-cell counts use this box.

![](./images/Picker_testbox.png)

5.  **Mark the cells:** click on the cell body of EVERY microglia inside the box with the multi-point tool (Alt-click removes a point), then click OK. Cells you skip are counted as non-cell particles.

![](./images/Picker_markcells.png)

6.  Wait for the run to finish. The Top 20 montage opens when done.

#### Options compared

Option names follow the pattern `C<contrast stretch>U<unsharp mask>D<despeckle>[_<background removal>]_<method>[_<splitting>]`, where 1 is on and 0 is off. For example, `C0U1D1_auto_Huang` is Program 2 standard preprocessing (unsharp mask radius 3, weight 0.6, plus despeckle, no contrast stretch) followed by a global Huang threshold.

- Global thresholds: Huang, Li
- Local thresholds: Niblack, Mean, Phansalkar (radius 100 px at 0.3447 um/px, rescaled to your pixel size)
- Hysteresis: local low threshold plus a global Otsu high mask
- Tubeness ridge filter: TubeOrig and Tube3Post at fixed minimum responses, or noise-relative cutoffs written as `k5`. Tubeness options are not combined with background removal
- Background removal before the other preprocessing: rolling ball (RB), sliding paraboloid (SP), white top-hat (TH), sizes in um
- Splitting: no suffix (unsplit), `_splitSoma` (soma-seeded split, default seed sigma 3 um and prominence 8), `_splitSoma_seedReq` (split plus the seed requirement). A non-default seed is written `_splitSoma_s2.0_p12`

#### How to read the montage panels

Colors in each panel:

- **Each kept particle has its own color** (when the colour option is ticked), otherwise white
- **Black dots with a white ring:** the cells you marked
- **Red:** particle removed (too small)
- **Cyan:** particle removed (too big)
- **Yellow:** line where touching cells were cut

The first tile of the Top 20 montage is your original image, contrast stretched for display only.

Look for ramified cells that are whole with their processes present, few non-cell particles in the background, touching cells that are separated, and thin branches that are not lost.


![](./images/Top20_Montage.png)


#### How the options are ranked

For every option and area filter, the macro counts inside the test box:

| Column | Meaning |
| ------ | ------- |
| Cells_marked | Number of cells you marked |
| Cells_recovered_alone | Marked cells found as their own particle |
| Cells_complete_alone | Marked cells recovered alone whose particle is not over-pruned (see below) |
| Median_completeness_pct | Median size of the particles of the marked cells, as a percentage of the typical particle for those cells across all options |
| Percent_recovered_alone | Cells_recovered_alone as a percentage of Cells_marked |
| Cells_in_merged_particles | Marked cells found, but fused with another cell in one particle |
| Cells_missed | Marked cells not found |
| Non_cell_particles | Particles kept that do not contain a marked cell |
| Over_grown_flag | The option's particles are too large for the marked cells (fused cells, see below) |
| Below_min_recovery | The option recovers too few of the marked cells to be ranked (`AllOptions_Ranked.csv` only, see below) |

**Net score = Cells_complete_alone minus Non_cell_particles.** The list is sorted by this score, with two exceptions:

- **Over-grown options are ranked below all other options.** If the median particle size for the marked cells is above the over-growth percentage (default 140%) of the usual size, the option is fusing cells together, even if few cells are counted as merged.
- **Options below the minimum recovery are not ranked.** An option that recovers (alone and complete) fewer than the minimum recovery percentage (default 25%) of your marked cells can have almost no non-cell particles simply because it removes nearly everything. These options are left out of the Top 20 and listed at the bottom of `AllOptions_Ranked.csv` with `Below_min_recovery` set.

An option appears once in `Top20_Options.csv`, at its best area filter. When two area filters give the same score, the larger filter is kept. `AllOptions_Ranked.csv` lists every option at every area filter.

#### The pruning check

Counting a cell as recovered when its particle contains the marked soma rewards options that keep the soma but cut off the branches (tight local thresholds such as Phansalkar are the usual example). To catch this, the macro takes the area of the particle containing each marked cell and compares it with the median of that cell's particle areas across all options. An option only gets credit for a cell if its particle is at least the **pruning check percentage** of that typical area (default 60). The per-cell areas are saved in `MarkedCellAreas.csv`.

The 60% default is a rule of thumb, not a validated cutoff. In one test run the particle sizes showed a gap between 55% and 65%, but check your own data: look at `Median_completeness_pct` in the ranked list and at the Top 20 montage, and raise or lower the percentage if good options are dropped or pruned options still rank high. Because the check is relative to the other options, it works best when the option list includes some options that keep the full branches. The over-growth check uses the same comparison in the other direction.

#### Output

Outputs are saved in a new folder next to the image, `SettingsTest_<image>/`:

| File | Contents |
| ---- | -------- |
| `Top20_Options.csv` | The best 20 options with their counts, net score and over-growth flag |
| `Top20_Montage.png` | Review panels of those options in rank order, starting with the original image. Rank and area filter are written on each panel |
| `AllOptions_Ranked.csv` | Every option at every area filter, ranked by the net score, with the over-growth and minimum recovery flags |
| `SettingsTest_Summary.csv` | Counts for every option and area filter, including the completeness columns and the background removal, `Seed_required` and `Particles_removed_no_seed` columns |
| `MarkedCellAreas.csv` | Area of the particle that contains each marked cell, for every option |
| `ReviewMontage_<image>_ALL.png` | Rows are options, columns are minimum area filters |
| `ReviewMontage_<image>_min<..>.png` | One montage per filter, first tile is the raw image |
| `SettingsKey.txt` | Tile number mapped to the exact settings of every option, and the 16-bit conversion used |
| `PreprocessBenchmark_Results.csv` | Particle counts and other metrics for each option and filter |
| `Masks/<option>/` | The binary mask of every option |



**Write down the full option name from `Top20_Options.csv`, its `Min_area_um2`, and the 16-bit conversion setting you used.** You will enter them in Step 2.
</details>

---

## Step 2. MicrogliaMorphologyProgram

**In short:** run *Plugins > MicrogliaMorphology > MicrogliaMorphology Program2.4* on the whole dataset. It has three steps: (1) preprocess and threshold, (2) split touching cells, (3) measure single cells. Run all three in one go, or start and stop at any of them. Choose the option you picked in Step 1 from the list, or paste its name, and the Program sets the preprocessing, threshold and splitting for you. Use the same 16-bit conversion setting as in the Picker. Step 3 can also measure the intensity of a second stain inside each microglia (see *Measuring intensity in another channel* below).

**What is new in Program 2.4:**

- **27 morphology columns:** hull_Feret, hull_MinFeret and hull_Solidity are no longer written. The hull's Feret diameters are the same as the cell's Feret and MinFeret, and the hull's solidity is about 1 for every cell, so these columns only duplicated information in PCA and clustering.
- **Intensity on the raw channel (optional):** the quantification channel keeps its own bit depth (for example 16-bit), and the cell shape always comes from the mask, so ticking quantification does not change the morphology columns.
- **Signal area and puncta count (optional):** the area, fraction, puncta count and intensity of the thresholded signal (for example CD68) inside each cell, with the threshold set and previewed on a small test area first.
- **Channels and pixel size:** the quantification channel is read correctly from hyperstacks and plain stacks; the pixel size is confirmed once at the start, and the masks are saved with their pixel size, so step 3 always measures in microns.


<details>
<summary>

   ### Program details: dialogs and settings
</summary>

#### First dialog: where to start and stop

![](./images/MicrogliaMorphologyDiaglog1.png)

- **Start at / Finish at:** choose the first and last of the three steps. You can begin at step 2 or 3 if the earlier steps are already done.
- **16-bit images: conversion to 8-bit:** percentile range (recommended) or full range. Use the same setting as in the Picker so the run matches what you ranked.
- **Create output folders automatically:** creates `ThresholdedImages`, `SplitImages` and `MeasurementResults` next to the input folder. If unticked you are asked to choose each output folder (they should be empty).

#### Settings from the TestImageSettingsPicker

If you start at step 1 or 2, a second dialog asks for the settings. You can choose them in one of two ways:

**1. List/Enter Full Entry**

![](./images/Dialog3a.png)

- **Pick from the lists:** choose one of the Picker's base options, then a splitting variant: soma-seeded split + seed requirement (`_splitSoma_seedReq`, the default), soma-seeded split (`_splitSoma`), or no splitting.
- **Paste the option name:** copy it from `Top20_Options.csv` or `AllOptions_Ranked.csv`, for example `C0U1D1_RB25_local_Mean_r100_splitSoma_seedReq`. A pasted name overrides the lists and also reads non-default seed settings, for example `C0U1D1_local_Niblack_r100_splitSoma_s2.0_p12_seedReq`.

The arm names and the settings file use the same names as the Picker, so the run matches what you ranked. If the name is not understood, the macro stops with a message. 

**The area filter is not taken from the option name.** Enter the Picker's best `Min_area_um2` in the area filter dialog in step 3. A reminder is shown there.



**2. Manual Entry**
To set everything manually, choose "(set every option myself in the next dialogs)" in the list. The dialogs then walk you through each set of options for background removal, preprocessing, and thresholding. 

![](./images/MicrogliaMorphologyDialog2.png)

#### Step 1 settings: preprocessing and thresholding (manual option only)

Step 1 has two dialogs: 1a (preprocessing) and 1b (segmentation). They appear only when you do not choose a Picker option.

![](./images/Dialog3.png)

![](./images/Dialog4.png)

- **Channel with the microglia signal** (leave at 1 for a single channel; the channel order must be consistent across images).
- **Background removal** before the other preprocessing: none, rolling ball, sliding paraboloid, Gaussian divide (flat-field) or white top-hat (needs MorphoLibJ), with the size in um. Background removal applies to the global, local and hysteresis approaches, not to Tubeness.
- **Preprocessing:** contrast stretch, unsharp mask (radius and weight) and despeckle, each on or off. The Program 2 standard is unsharp mask plus despeckle (C0U1D1).
- **Segmentation approach:** auto thresholding (global), auto local thresholding, hysteresis, or Tubeness ridge filter.
  - Global: choose the method (for example Huang).
  - Local: choose the method (for example Niblack) and the radius as written in the Picker option name (for example 100).
  - Hysteresis: a local low threshold, keeping only particles that also contain a pixel of a strict global high threshold (Otsu by default).
  - Tubeness: choose the variant, the minimum response (a number such as 20, or noise-relative such as k5) and the soma layer (mean + N x SD).
- Program 2 post-processing (Despeckle, Close-, Remove Outliers) is always applied to global and local options. Tubeness uses the post-processing of its variant.

#### Step 2 settings: splitting touching cells (manual option only)

![](./images/Dialog5.png)

- **No splitting** or **Soma-seeded split (recommended).** One seed is placed per soma from the blurred original image and the mask is cut along watershed lines between seeds. A cell with branches is not cut.
- **Seed blur sigma (um)** (default 3) and **prominence** in 8-bit grey levels (default 8).
- **Seed requirement** (optional): particles with no soma seed are removed as non-cell objects.
- Splitting replaces the old upper area filter. Only particles at or above the minimum area are split.

#### Step 3 settings: area filters and measurements

![](./images/Program_areafilters.png)

- **Lower cell area filter (um^2):** removes small non-cell particles (default 100). Use the `Min_area_um2` of the Picker option you chose.
- **Upper cell area filter (um^2, 0 = none):** no longer needed because touching cells are separated in step 2. Set it only to remove large debris.
- **Do your images have ROIs traced?**
- **Quantify a fluorescence signal in the microglia?** and which channel. This can be used to compare morphology between stain-positive and stain-negative cells. The channel can be the microglia channel. If you start at step 3, you are asked for the original images again to read this channel.
- **Also measure the signal area and puncta count in that channel?** Opens a second dialog to choose how signal pixels are found, with an option to test the settings on an example image (see *Measuring intensity in another channel* below).

#### Measuring intensity in another channel within the microglia

Step 3 can measure the fluorescence of a second stain inside each microglia, for example a marker of activation, phagocytosis or a reporter. This lets you compare the morphology of marker-positive and marker-negative cells, or relate marker level to cell shape.

**What you need**

- Multi-channel original images, with the microglia channel and the channel to quantify in the same file. The channel order must be the same in every image. Hyperstacks and plain stacks with one channel per slice both work; the Log reports how many channels each image has and which one is used.
- The masks from step 1 or 2. The cell outlines always come from the microglia mask. The second channel is only read inside those outlines, so it does not change which cells are found or their shape.

**How to run it**

1.  In the step 3 dialog, tick **"Quantify a fluorescence signal in the microglia?"** and enter the channel number to quantify. It can be the microglia channel itself, for example to measure Iba1 intensity.
2.  When the folders are chosen, you are asked for the folder of original images. The Program finds each image's original by matching the start of the mask name to the original file name. If no original is found for an image, its cells are measured without intensity and a message is written to the Log.

**What you get**

Five extra columns in each `MeasurementResults/<image>.csv`:

| Column | Meaning |
| ------ | ------- |
| Mean | Mean grey value of the quantification channel inside the cell |
| Min, Max | Lowest and highest grey value inside the cell |
| IntDen | Integrated density inside the cell (Area x Mean) |
| hull_IntDen | Integrated density inside the convex hull of the cell. This includes the space between the processes, so it reflects signal around the cell as well as in it |

**Signal area and puncta count (optional)**

Intensity tells you how bright the stain is in each cell. For punctate stains such as CD68 it is often more useful to know how much of the cell is covered by signal. Tick **"also measure the signal area and puncta count in that channel"** under the quantification checkbox. The settings are then chosen on a small test area of one image, so each preview is quick:

1.  **Choose a test image:** one original image that contains the channel you are quantifying, ideally with clear positive signal. Its channel opens straight away. (You can also skip the test and set the options without previewing them.)
2.  **Place the test area:** drag the yellow box to a representative area and resize it if needed (default about 200 x 200 um). Smaller is faster. The image is cropped to the box.
3.  **Set the options and apply.** The settings window lists the options in the order they are applied:
    - **1. Background:** **background subtraction** (rolling ball radius in um, default 5, 0 = off) and **smoothing** (Gaussian sigma in um, default 0 = off). These are applied before thresholding, so the threshold, including a fixed value, is on the scale of the background-corrected channel.
    - **2. Threshold:** the **thresholding method** (below), the **fixed value**, the **auto threshold method**, and the **smallest punctum counted** (um^2, default 0.2; signal particles smaller than this are ignored for both the area and the count). At 0.3447 um per pixel, 0.2 um^2 is about 2 pixels, close to the resolution limit. If the preview shows specks that are not real signal, raise it to about 0.3 to 0.5 um^2; this mainly lowers the puncta count and changes the signal area little.
    - **3. Next:** choose **Apply** and click OK to preview the settings on the test area. A second window, **Background-corrected test area**, opens next to the test area and shows the channel after background subtraction and smoothing, which is what the threshold is applied to, so you can see the effect of the background settings. The signal is outlined in yellow on both, and the **Results** box at the top of the window shows the threshold used, the % of the test area covered by signal, and the number of puncta (also per 1000 um^2). Both windows are displayed with the same fixed brightness range (0 to the bright end of the test area) for every Apply. This is display only: the pixel values are not rescaled, so a darker background-corrected window means the background really was lowered. The window comes back so you can change the options and apply again. Repeat until the yellow outlines follow the real signal and not the background, then choose **Proceed to the next step** and click OK. (ImageJ macro windows only have OK and Cancel buttons, so Apply and Proceed are the two choices above OK. Cancel stops the macro.)

The thresholding methods. The channel is thresholded once per image, not per cell, so a cell with no signal gets a signal area of 0:

- **Fixed value:** pixels at or above a grey value you enter. The same rule is used for every image, so it is the most comparable across conditions when all images were taken with the same settings. Choose the value with the preview, ideally checking images from both control and treated animals.
- **Auto threshold (calculated for each image):** an ImageJ method (Otsu, Triangle, MaxEntropy and others) run separately on every image. It corrects for brightness differences between images, but because the cutoff moves with each image, part of a real change in signal between conditions can be thresholded away, and an image with little real signal can still have background called "signal". Use it mainly when staining or imaging is inconsistent. After the run, check the cutoffs in `SignalThresholds.csv`: if they differ between your groups, the threshold is partly tracking the biology, and a fixed value is the safer choice.
- **Auto threshold from the test area, then used as a fixed value:** the chosen ImageJ method is run once on the test area, and that value is used as a fixed value for every image. This gives an objective value with the same cutoff everywhere. It needs a test area, and the value is recalculated with the final settings when you proceed. Because it is calculated on the test area only, place the test area on tissue that is typical for your dataset.

The Log lists how many channels the test image has, which one is used, and where the test area was placed.

Five more columns are added to each `MeasurementResults/<image>.csv`:

| Column | Meaning |
| ------ | ------- |
| Signal_area | Area of the cell covered by signal, in um^2 |
| Signal_fraction | Signal_area divided by the cell Area (for example CD68 area / microglia area) |
| Puncta_count | Number of separate signal particles in the cell, at or above the smallest punctum size |
| Signal_mean | Mean grey value of the quantification channel within the signal pixels of the cell only (raw values, before background subtraction). NA when the cell has no signal, because there are no pixels to average |
| Signal_IntDen | Integrated density within the signal pixels of the cell only (Signal_area x Signal_mean) |

A cell with no signal gets Signal_area 0, Signal_fraction 0, Puncta_count 0, Signal_IntDen 0 and Signal_mean NA. The signal columns all describe the same pixels: signal pixels inside the cell outline, in particles at least the smallest punctum size. The threshold used for every image is saved in `SignalThresholds.csv` in the main folder (next to `Areas.csv`) (columns Image, Method, Threshold), and the settings are in `FinalDatasetParameters_<date-time>.txt`.

**Things to check**

- **Intensity is measured on the raw channel.** The quantification channel keeps its original bit depth (for example 16-bit), so the values are the raw grey values and can be compared between images, as long as all samples were imaged with the same settings. The 16-bit to 8-bit conversion setting only affects thresholding, not these values.
- **The cell shape always comes from the mask.** Intensity is read inside the same cell and hull outlines that are measured for morphology, so ticking quantification does not change the morphology columns.
- Z-stacks are not projected for quantification. Use single-plane (or max projected) original images.
- Background is not subtracted from the intensity values. Mean, IntDen, Signal_mean and Signal_IntDen are all raw values; the background subtraction in the signal settings is only used to decide which pixels count as signal. If the background differs between images, measure it in a cell-free area and subtract it, or normalize the intensities to the image background in R.
- **Remove these columns from the morphology clustering.** The intensity and signal values (Mean, Min, Max, IntDen, hull_IntDen, and with the signal option Signal_area, Signal_fraction, Puncta_count, Signal_mean and Signal_IntDen) are not morphology features. In MicrogliaMorphologyR, remove them from the dataframe used as input for the morphology analysis, then merge them back in by cell ID after the morphology assignments to quantify levels within each morphology class.

#### Summary of your settings

A summary of your settings is shown before the folders are chosen. Check it against the option you picked in the TestImageSettingsPicker, and check that the lower area filter matches the Picker's `Min_area_um2`.

![](./images/Program_summary.png)

#### Folders and image range

Choose the input folder (original images when starting at step 1; thresholded masks plus original images when starting at step 2; final masks when starting at step 3). Then choose which range of images to process. Files are sorted alphabetically, so "Test_image_1.tif", "Test_image_10.tif" and "Test_image_9.tif" are listed in that order.

#### Pixel size check

Before the run starts, the macro reports the pixel size it reads from the first image and asks you to confirm it. If it is wrong, untick the box and enter the correct pixel width in microns. The value is used for every image in the run. (If you set a signal threshold on a test image, this check happens when the test image opens.)

- Any later image without a pixel size uses the value accepted here, so you are not asked again once the run has started. A note is written to the Log for each such image.
- The thresholded masks (step 1) and split masks (step 2) are saved with the pixel size of their original image, so step 3 reads them in microns.
- To check, open a mask and look at *Image > Properties*: the unit should be microns. In the measurement files, Area has decimals and is in um^2. Whole-number areas mean the cells were measured in pixels, and the area filters were then applied in pixels too.

![](./images/Program_pixelsize.png)
</details>

<details>
<summary>

   ### Program details: outputs
</summary>

All outputs are placed next to the input folder.

| Output | Description |
| ------ | ----------- |
| `ThresholdedImages/<image>_thresholded.tif` | Step 1 masks |
| `SplitImages/<image>_thresholded.tif` | Step 2 masks with touching cells separated |
| `MeasurementResults/<image>.csv` | Step 3: one .csv per input image with one row per cell |
| `Areas.csv` | Area of each image (or of the ROIs within it). Use it in MicrogliaMorphologyR to calculate density (cells / area analyzed) |
| `SplitLog.csv` | Record of the splitting step |
| `FinalDatasetParameters_<date-time>.txt` | Every setting used in the run, including the 16-bit conversion and the signal quantification settings, for your records. Keep it with your data |
| `SignalThresholds.csv` | Only with the signal area and puncta count: the thresholding method and threshold used for every image |

Each row of a measurement file is one cell, with these columns:

|Output | Description |
| ----- | ----------- |
| Label | The name of the individual ROI, sometimes fused to the image and region name |
| Image | The image name |
| Region | The region name. If no region was present or "Do your input images have ROIs" was unselected this says "full_brain" |
| Area | Area of the cell |
| Optional: Mean, Min, Max, IntDen, hull_IntDen | The mean, minimum, maximum and integrated density of the grey intensity in the quantification channel, when quantification was ticked |
| Perim. | Perimeter of the cell |
| Major | Major radius of the fit ellipse |
| Minor | Minor radius of the fit ellipse |
| Circ. | Circularity, the relationship between area and perimeter of the cell |
| Feret | The major Feret's caliper of the cell |
| MinFeret | The minor Feret's caliper of the cell |
| Round | The roundness of the cell |
| Solidity | The solidity of the cell |
| hull_X | The same measure but applied to the convex hull of the cell, for Area, Perim., Major, Minor, Circ. and Round. With quantification ticked, hull_IntDen is also added |
| Hull span ratio | The ratio between the major and the minor Feret's caliper of the convex hull (the same calipers as Feret and MinFeret, so it equals Feret / MinFeret) |
| Max/min radii from hull | The ratio between the maximum radius of the convex hull and the smallest radius of the convex hull. Radius is taken to the center of mass of the convex hull |
| Relative variation (CV) hull | The coefficient of variation (CV) of all long radii (distance from center of mass to corners of convex hull) and all short radii (distance from center of mass to closest point on edge of convex hull) |
| skeleton_X | Results from the Analyze Skeleton function |
| Optional: Signal_area, Signal_fraction, Puncta_count, Signal_mean, Signal_IntDen | Signal area and puncta count in the quantification channel, when that option was ticked (see *Measuring intensity in another channel*) |
</details>

---

## Step 3. Cluster the cells in R with MicrogliaMorphologyR

**In short:** use the measurement .csv files and `Areas.csv` as input to [MicrogliaMorphologyR](https://github.com/ciernialab/MicrogliaMorphologyR). It clusters the microglia into distinct morphological states and produces the label files that CBC needs.

<details>
<summary>

   ### MicrogliaMorphologyR details
</summary>

Available at [github.com/ciernialab/MicrogliaMorphologyR](https://github.com/ciernialab/MicrogliaMorphologyR). For the MicrogliaMorphology Pipeline 2 workflow example, see the [Pipeline 2 tutorial](https://ciernialab.github.io/MicrogliaMorphologyR/articles/MicrogliaMorphologyPipeline2.html). One of its outputs is a set of ColorByCluster label files, which provide the information used to color the original microglia by cluster in Step 4.
</details>

---

## Step 4. CBC (ColorByCluster)

**In short:** run *Plugins > MicrogliaMorphology > MicrogliaMorphology ColorByCluster*, choose the folders of original images, final masks and cluster label files, pick a color for each cluster, and the macro saves the original images with each microglia colored by its cluster.

<details>
<summary>

   ### ColorByCluster details
</summary>

ColorByCluster lets you color the microglia in your original immunofluorescent images by their cluster identities. It is the companion to the output of MicrogliaMorphologyR (see the [ColorByCluster section](https://ciernialab.github.io/MicrogliaMorphologyR/articles/MicrogliaMorphologyPipeline2.html) of that repo) and is a way to visually validate morphological clusters and see their spatial distribution in the brain. It colors one image at a time or batch processes a group of images.

#### You will need

- The original immunofluorescent .tiff image(s) that were input into MicrogliaMorphology.
- The final mask .tiff image(s) that were measured, with the original image name as the starting string (the .tif extension is not needed). Use the images from `SplitImages` if you split touching cells, so that the cell IDs match the label files.
- The ColorByCluster labels .csv file(s) generated using [MicrogliaMorphologyR](https://github.com/ciernialab/MicrogliaMorphologyR#colorbycluster), with the corresponding original image name as the starting string.

All three sets of files must have the same starting string, ideally the name of the original image.

#### Label file format

A column with an empty first row and ascending numbers after that; a column named "Cluster"; a column named "ID" with content matching the single-cell ROI labels; and a column named "Region" with names matching the analyzed regions, or "full_brain" if no regions were provided:

|   | Cluster | ID | Region |
| - | -------- | --- | ------ |
| 1 | 2 | 0001-0034 | Region1 |
| 2 | 1 | 0001-0026 | Region2 |
| 3 | 1 | 0002-0193 | Region2 |
| 4 | 3 | 0003-0351 | Region2 |
| 5 | 1 | 0001-0039 | Region3 |
| 6 | 3 | 0002-0062 | Region3 |
| 7 | 2 | 0003-0175 | full_brain |
| 8 | 2 | 0004-0290 | full_brain |

#### Procedure

1.  Choose the parent folder of the original images, the folder of final masks, and the folder of cluster label .csv files.
2.  Choose an output folder for the colored images.
3.  Choose the channel to color (leave at 1 for a single channel).
4.  Set a color for each cluster (up to 10). Use a HEX code such as `BBCC33`, or one of: black, white, cyan, magenta, yellow, red, green, blue, orange.

Output: `<image>_ColorByCluster.tif` for every original image that has both a matching mask and a matching label file.
</details>

---

## Optional: CountMicroglia

**In short:** run *Plugins > MicrogliaMorphology > MicrogliaMorphology CountMicroglia v3* on multi-channel images with a microglia stain (Iba1) and a nuclear stain (DAPI). Each DAPI nucleus is counted as a microglia when it sits inside or touches an Iba1 cell body. Counts, area and density (cells/mm^2) are reported per region.

**What is new in v3:** a second way to split touching nuclei (watershed seeded by DAPI intensity peaks, run in tiles so it is fast on large images), nuclei that share one soma mask are only merged when they are close together (default 15 um), a two-channel review image (`NAME_review.tif`) for checking cells channel by channel, an option to choose the output folder, and the dialog remembers your last settings.

**Recommended workflow:** tune the settings on one test image first, then run the batch.

1.  Open one representative multi-channel image and run the macro in **single image** mode with **"Mark cells now"** validation. Click once on every microglia you can identify.
2.  Check the QC image, the review image, the two mask images and the validation numbers (TP, FP, FN, precision, recall, F1).
3.  Change one setting at a time (see the tuning guide below), re-run on the same image, and keep the settings that give the best F1.
4.  Confirm the settings on two or three more images from different animals, conditions or regions.
5.  Run **batch** mode on the whole folder with validation turned off.

<details>
<summary>

   ### CountMicroglia details: running the macro
</summary>

#### Input

A multi-channel TIF (hyperstack). Z-stacks are max projected per channel. The pixel size is read from the image calibration. If there is none, the fallback value from the dialog is used, or you are asked.

#### First dialog

![](./images/Count_dialog.png)

The dialog remembers the settings from your last run, including the advanced parameters.

- **Mode:** single image (uses the open image; drawing ROIs and marking cells are available) or batch (every .tif/.tiff in a folder).
- **Microglia (Iba1) channel** (default 2) and **Nuclear (DAPI) channel** (default 1). Tick the box if the channels are slices of a plain stack rather than a hyperstack.
- **Regions:** whole image, ROIs saved in the TIF (selection and/or overlay), an ROI .zip next to the image (`NAME.zip`, `NAME_RoiSet.zip`, `NAME_ROI.zip`, `NAME_ROIs.zip` or `RoiSet.zip`), or ROIs drawn now (single image mode). Choose whether to skip images without ROIs or count the whole image. A nucleus belongs to an ROI when its centroid lies inside it. Segmentation is done on the whole image, so thresholds do not depend on the ROI.
- **Validation with hand-marked cells:** none, existing marks, or mark cells now (single image only).
- **Pixel size** if the image has none (0 = ask).
- **Choose where to save the output.** If unticked, results go to a subfolder `CountMicroglia_output` next to the images.
- **Save QC images** and **Save nucleus and soma masks (TIF)**. Keep both ticked while tuning. The QC option saves both the QC PNG and the review TIF.
- **Show advanced parameters next** opens the second dialog (tick it while tuning).
- **Verbose log** for debugging. The log shows each step with a time stamp, so you can see where a run stopped.

#### Advanced parameters

All sizes are in microns and use the image pixel size.

![](./images/Count_advanced.png)

| Group | Setting | Default | What it does |
| ----- | ------- | ------- | ------------ |
| Nuclei (DAPI) | Smoothing sigma | 0.5 um | Blur before thresholding |
| | Background rolling ball radius | 15 um | Removes uneven background (0 = off) |
| | Threshold method | Li | Automatic threshold for nuclei |
| | Threshold multiplier | 1.00 | Multiplies the automatic threshold. Above 1 is stricter |
| | Split touching nuclei | Distance watershed | None, distance watershed (shape based), or DAPI intensity peaks (seeded watershed, one nucleus per DAPI peak) |
| | DAPI peak splitting: smoothing sigma | 1.00 um | Blur of the DAPI image used to find one peak per nucleus (DAPI peak mode only) |
| | DAPI peak splitting: prominence | 0.20 x threshold | How far a peak must stand above its surroundings, as a fraction of the nuclear threshold. Lower splits more (DAPI peak mode only) |
| | Smallest nucleus kept | 15 um^2 | Smaller particles are ignored |
| | Flag nuclei larger than | 200 um^2 | Large nuclei are flagged as possible merged nuclei |
| Iba1 cell body (soma) mask | Smoothing sigma | 1.00 um | Blur before thresholding |
| | Background rolling ball radius | 25 um | Keep larger than a soma (0 = off) |
| | Threshold method | Huang | Automatic threshold for Iba1 |
| | Threshold multiplier | 1.40 | Above 1 is stricter |
| | Close gaps up to radius | 1.50 um | Closes gaps in the Iba1 ring around a nucleus |
| | Fill holes up to | 120 um^2 | Fills the hole a nucleus makes in the Iba1 ring |
| | Remove processes thinner than 2 x | 3.50 um | Opening step that leaves the somata and removes thin processes |
| | Dilate soma mask (touching) | 0.50 um | Lets a nucleus that touches a soma count |
| Decision and validation | Min fraction of nucleus inside soma mask | 0.65 | `Min_overlap` |
| | Min Iba1 over the nucleus (x Iba1 threshold) | 2.00 | `Iba1_k` |
| | Merge nuclei that share a soma mask | on | Keeps the nucleus with the most Iba1 |
| | ...only if closer together than | 15 um | Nuclei in the same soma mask that are farther apart are counted as separate cells |
| | Mark matching distance | 6.0 um | How close a mark must be to a nucleus to match |

#### Marking cells for validation

In single image mode with **"Mark cells now"**, click once on every microglia in the region you want to validate (a cell with a DAPI nucleus inside or touching an Iba1 cell body). If you use ROIs, mark only inside them. Then click OK. The marks are saved to `NAME_marks.csv` next to the image so they can be reused in later runs and in batch mode. Marks stored as a multi-point ROI in the image or the ROI .zip are also read.

![](./images/Count_mark.png)

#### Method

1.  **Nuclei:** smooth, subtract background, auto threshold, fill holes, optional splitting of touching nuclei (distance watershed, or a watershed seeded by DAPI intensity peaks, which runs in 1024 px tiles so it stays fast on large images), size filter.
2.  **Iba1 cell bodies:** smooth, subtract background, auto threshold, close small gaps, fill small holes (a nucleus is a hole in the Iba1 ring), open to remove thin processes (leaves somata), dilate slightly so "touching" counts.
3.  **Decision for each nucleus:** it is counted as a microglia when enough of its area lies inside the soma mask (`Soma_overlap` at or above `Min_overlap`) AND the Iba1 signal over the nucleus is high enough (`Iba1_on_nucleus` at or above `Iba1_k` x the Iba1 threshold). A nucleus enclosed by Iba1 processes but with no Iba1 signal on it is rejected. Optionally, nuclei in the same connected soma mask that lie closer than the merge distance (default 15 um) are merged and only the one with the highest Iba1 is kept; the others are listed with `Reason = Shared_soma`. Nuclei farther apart in the same soma mask are counted as separate cells.
4.  Counts per region, area (mm^2) and density (cells/mm^2).

#### Limits

- A max projection can merge nuclei at different depths, and a microglia whose nucleus is not in the DAPI projection cannot be counted.
- Only the first time point is used for time series.
</details>

<details>
<summary>

   ### CountMicroglia details: results and how to interpret them
</summary>

#### Output files (folder `CountMicroglia_output`, or the folder you chose)

| File | Contents |
| ---- | -------- |
| `CountMicroglia_Summary.csv` | One row per image and region (batch) |
| `NAME_summary.csv` | Same, in single image mode |
| `NAME_nuclei.csv` | One row per nucleus (area, soma overlap, class, reason, region) |
| `NAME_QC.png` | The QC image (see below) |
| `NAME_review.tif` | Two-channel image (Iba1 green, DAPI blue) with the same outlines as an overlay (see below) |
| `NAME_nucmask.tif`, `NAME_somamask.tif` | Nucleus and soma masks (optional) |
| `CountMicroglia_Settings.txt` | All parameters used |

#### The QC image

The QC image shows Iba1 in green and DAPI in blue, with every nucleus outlined and numbered. The legend is written at the top of the image.

![](./images/Count_QC.jpg)

| Mark | Meaning |
| ---- | ------- |
| Red outline | Counted as microglia, and you marked it |
| Magenta outline | Counted as microglia, but you did not mark it (false positive, FP) |
| Yellow outline | Rejected (not counted as microglia) |
| Orange outline | Dropped because it shares a soma mask with a nearby nucleus that has more Iba1 |
| Gray outline | Iba1 soma mask |
| Cyan circle | A mark that matched a counted nucleus (true positive, TP) |
| White circle | A mark with no counted nucleus (false negative, FN) |

The header reports the validation result. In this example it reads **TP 52, FP 24, FN 22** and **76 microglia of 1959 nuclei** in the whole image.

#### The review image

`NAME_review.tif` has Iba1 and DAPI as separate channels, with the same outlines as an overlay. Open it in Fiji and use *Image > Color > Channels Tool* (Shift+Z) to switch between the merged view and one channel at a time. This makes it easier to judge whether a nucleus really sits in an Iba1 cell body, or whether a cell you marked has a DAPI nucleus at all.

#### The mask images

Check both masks before trusting the counts.

**Nucleus mask** (`NAME_nucmask.tif`). Each white shape should be one nucleus. Thin dark lines inside a white blob are the watershed cuts that separate touching nuclei. Look for nuclei that are merged into one blob (they are flagged in `Large_nuclei_flagged`), nuclei that are missing, and background specks that are counted as nuclei.

![](./images/Count_nucmask.png)

**Soma mask** (`NAME_somamask.tif`). The white shapes should be the Iba1 cell bodies, with the thin processes removed. A microglia is only counted if its nucleus overlaps this mask, so a soma that is missing here cannot be counted, and a blob that covers several nearby nuclei can lead to nuclei being dropped as `Shared_soma`.

![](./images/Count_somamask.png)

#### The summary table

One row per image and region. The columns to read first:

| Column | Meaning |
| ------ | ------- |
| `Region_area_mm2` | Area analyzed |
| `Nuclei_total` | All nuclei found in the region |
| `Microglia_count` | Nuclei counted as microglia |
| `Other_nuclei` | Nuclei not counted as microglia |
| `Microglia_per_mm2`, `Nuclei_per_mm2` | Densities |
| `Pct_nuclei_microglia` | Microglia as a percentage of all nuclei |
| `Large_nuclei_flagged` | Nuclei larger than the flag size (possible merged nuclei) |
| `Dropped_shared_soma` | Nuclei dropped because they share a soma mask with a nearby nucleus |
| `Min_overlap`, `Iba1_k`, `One_per_soma`, `Nuc_threshold`, `Iba1_threshold` | Settings and thresholds used |
| `Pixel_size_um`, `Pixel_size_source` | Pixel size used and where it came from (image, fallback or entered) |
| `Marks`, `TP`, `FP`, `FN` | Validation counts (when you marked cells) |
| `FN_nucleus_rejected` | Missed cells where a nucleus was found but rejected |
| `FN_no_nucleus` | Missed cells where no nucleus was found at all |
| `Precision`, `Recall`, `F1` | See below |
| `Warnings` | Messages from the run, such as a missing pixel size |

The nuclei table (`NAME_nuclei.csv`) has one row per nucleus. `Class` is Microglia or Other, and `Reason` says why: `Microglia`, `Low_soma_overlap`, `Low_Iba1_on_nucleus` or `Shared_soma`. It also has `Soma_overlap`, `Iba1_on_nucleus`, `Iba1_ratio` (Iba1 over the nucleus divided by the Iba1 threshold), `Soma_component` (which soma mask the nucleus overlaps) and `Large_flag`.

#### Validation measures

- **Precision** = TP / (TP + FP). How many of the counted microglia are real. A low value means too many false positives.
- **Recall** = TP / (TP + FN). How many of the cells you marked were counted. A low value means missed microglia.
- **F1** = 2 x TP / (2 x TP + FP + FN). A single score that balances both. Use it to compare settings.

In the example above, TP 52, FP 24 and FN 22 give 74 marked cells, precision 0.68, recall 0.70 and F1 0.69. Errors are split about evenly between false positives and missed cells, so look at `FN_nucleus_rejected` and `FN_no_nucleus` and at the `Reason` column to see what to change.
</details>

<details>
<summary>

   ### CountMicroglia details: tuning the settings before the full batch
</summary>

Change **one setting at a time**, re-run on the same test image with the same marks, and compare F1, precision and recall. Always look at the QC image, the review image and the masks as well as the numbers.

#### Step 1: check the nuclei

Open the nucleus mask and QC image. If nuclei are wrong, fix this first because every later step depends on it.

| What you see | What to change |
| ------------ | -------------- |
| `FN_no_nucleus` is high: marked cells have no nucleus outline | Lower the nucleus threshold multiplier (below 1 is more permissive), reduce the nucleus background radius or smoothing, or lower "Smallest nucleus kept". Also check that the DAPI channel number is right |
| Background specks outlined as nuclei | Raise the nucleus threshold multiplier or raise "Smallest nucleus kept" |
| Touching nuclei fused into one blob (`Large_nuclei_flagged` is high) | Make sure splitting is on. If the distance watershed does not separate them, switch to **DAPI intensity peaks** and lower the peak prominence. You can also raise the nucleus threshold multiplier slightly, or lower the smoothing sigma |
| One nucleus cut into pieces | With distance watershed: raise the smoothing sigma or turn off splitting. With DAPI intensity peaks: raise the peak prominence or the peak smoothing sigma |

#### Step 2: check the Iba1 soma mask

Open the soma mask. It should cover the cell bodies and not the processes.

| What you see | What to change |
| ------------ | -------------- |
| Somata missing from the mask | Lower the Iba1 threshold multiplier, or lower "Remove processes thinner than 2 x" |
| Mask covers processes and fibres as well as somata | Raise the Iba1 threshold multiplier, or raise "Remove processes thinner than 2 x" |
| Several neighboring cells merged into one blob | Raise "Remove processes thinner than 2 x", or lower "Close gaps up to radius". Nuclei more than the merge distance apart are still counted separately |
| Nuclei with Iba1 around them are not inside the mask | Raise "Fill holes up to" or "Close gaps up to radius", or raise "Dilate soma mask" |

#### Step 3: tune the decision rule

Use the `Reason` column in `NAME_nuclei.csv` and the `FN_nucleus_rejected` column to see why marked cells were rejected.

| What you see | What to change |
| ------------ | -------------- |
| Marked cells rejected with `Low_soma_overlap` | Lower **Min fraction of nucleus inside soma mask** (for example 0.65 to 0.5), or increase "Dilate soma mask" |
| Marked cells rejected with `Low_Iba1_on_nucleus` | Lower **Min Iba1 over the nucleus** (for example 2.0 to 1.5). Check `Iba1_ratio` for the missed cells to pick a value |
| Marked cells dropped as `Shared_soma` | Two nearby nuclei share one soma mask. If they are really two cells, lower the merge distance (default 15 um), untick "Merge nuclei that share a soma mask", or split the soma mask (raise the opening size). If one is a neighboring non-microglia nucleus, leave it on |
| Many magenta outlines (counted but not marked) | Check them in the review image. If they are not microglia, raise Min fraction inside soma mask, raise Min Iba1 over the nucleus, or raise the Iba1 threshold multiplier. If they are real microglia you did not mark, add marks and re-run |
| Many white circles with no outline (FN, `FN_no_nucleus`) | Go back to Step 1, nuclei were not found |
| Marks miss only because they are slightly off the nucleus | Increase the mark matching distance |

A general rule: **raising** Min overlap, Min Iba1 or the Iba1 multiplier makes counting stricter (fewer false positives, more misses). **Lowering** them makes it more permissive (fewer misses, more false positives). Stop when precision and recall are both acceptable for your question.

#### Step 4: confirm before the batch

1.  Re-run with the final settings and note the F1.
2.  Test on two or three more images that differ in staining, brightness or region. Mark a smaller region in each. If F1 drops a lot, the settings are too specific to the first image.
3.  Check `CountMicroglia_Settings.txt` to confirm what was used.
4.  Turn validation off and run **batch** mode on the whole folder. Check the `Warnings` column in `CountMicroglia_Summary.csv` and look at a few QC images from the batch.
5.  Use the same settings for every image in a comparison so that counts are comparable across groups.
</details>
