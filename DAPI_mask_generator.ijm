image = getTitle();
print(image);
setBatchMode(true);
run("Duplicate...", "title=mask");
// change here "Li" to another thresholding method
setAutoThreshold("Li dark no-reset");
//setThreshold(min,max);
//setThreshold(100,65535);
run("Convert to Mask");
// change here the size of median filter (smoother)
run("Median...", "radius=5");

// run Recorder to see what binary operation will be suitable
// could use MorphoLibJ for multiple binary operations;
run("Fill Holes");
run("Morphological Filters", "operation=Closing element=Square radius=9");
run("Watershed");
// run Recorder to see what binary operation will be suitable
// could use MorphoLibJ for multiple binary operations;


close("mask");
setBatchMode(false);
// size filter in Analyze Particle 50-Infinity
run("Analyze Particles...", "size=50-Infinity pixel exclude add");
selectWindow(image);
roiManager("Deselect");
roiManager("Measure");

