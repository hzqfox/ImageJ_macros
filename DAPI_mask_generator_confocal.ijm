#@ File(label="Select confocal lif file", style="extensions:lif") lifFile

setBatchMode(true);
	// get file and filename and file path
	fileName = File.getName(lifFile);
	fileNameWithoutExtension =  File.nameWithoutExtension;
	fileDir = File.getParent(lifFile);

	// create result folder
	resultDir = fileDir + File.separator + fileNameWithoutExtension + "_output";
	if (!File.exists(resultDir)) File.makeDirectory(resultDir);
	resultDirRaw = fileDir + File.separator + fileNameWithoutExtension + "_output" + File.separator + "raw";
	resultDirMask = fileDir + File.separator + fileNameWithoutExtension + "_output" + File.separator + "mask";
	if (!File.exists(resultDirRaw)) File.makeDirectory(resultDirRaw);
	if (!File.exists(resultDirMask)) File.makeDirectory(resultDirMask);
	
	// call bio-format macro extension and set parameters of the image (all series contained within a single lif file)
	run("Bio-Formats Macro Extensions");
	
	Ext.setId(lifFile);
	Ext.getSeriesCount(seriesCount);
	Ext.getSizeC(sizeC);
	Ext.getSizeZ(sizeZ);
	Ext.getSizeT(sizeT);
	
	print("Series count: "+seriesCount);
	print("channel count: "+sizeC);
	print("Z count : "+sizeZ);
	
	for (i=0; i<seriesCount; i++) {
	
		currentSeries = i;
		Ext.setSeries(currentSeries);

		Ext.openImage(lifFile,0);
		rename("C1");
		Ext.openImage(lifFile, 1);
		rename("C2");
		Ext.openImage(lifFile, 2);
		rename("C3");

		run("Merge Channels...", "c1=C1 c2=C2 c3=C3 create");
		
		//Ext.openImage(lifPath,0);
		//run("Cyan");
		//run("Enhance Contrast", "saturated=0.35");
		saveAs("tiff", resultDirRaw + File.separator + d2s(i+1,0) +".tiff");
		
		imgName = getTitle();
		print(imgName);

		run("Duplicate...", "title=mask duplicate channels=3-3");
		//imgDir = getDirectory("image"); 
		//imgDir = "I:/research/mnlab/data/shared_folders/light_microscopy/Yoko/181022_Confocal_cover180905_ERrasxWZL-LMNs_4LA-5k9m3/R-vec/";
		//setBatchMode(true);
		//run("Duplicate...", "title=mask");
		ID = getImageID();
		// change here "Li" to another thresholding method
		setAutoThreshold("Triangle dark no-reset");
		run("Convert to Mask");
		// change here the size of median filter (smoother)
		run("Median...", "radius=5");
		
		// run Recorder to see what binary operation will be suitable
		// could use MorphoLibJ for multiple binary operations;
		run("Fill Holes");
		//run("Morphological Filters", "operation=Closing element=Square radius=9");
		//run("Watershed");
		run("Morphological Filters", "operation=Opening element=Octagon radius=6");
		
		// run Recorder to see what binary operation will be suitable
		// could use MorphoLibJ for multiple binary operations;
		
		selectWindow("mask-Opening");
		
		
		//close("mask");
		//setBatchMode(false);
		// size filter in Analyze Particle 50-Infinity
		run("Set Measurements...", "area mean standard redirect=None decimal=3");
		run("Analyze Particles...", "size=50-Infinity pixel exclude add");
		selectWindow(imgName);
		roiManager("Deselect");
		roiManager("Measure");
		
		//selectImage(ID);
		close("mask");
		
		selectWindow("mask-Opening");
		rename("mask");
		changeValues(254,255,1);
		run("Select None");
		run("Remove Overlay");
		//saveAs("tiff", resultDir + File.separator + d2s(i,0) +"_C3.tiff");saveAs("tiff", resultDir + File.separator + d2s(i,0) +"_C3.tiff");
		saveAs("tif",resultDirMask + File.separator + d2s(i+1,0) +"_Object Predictions.tif");
	}
	
run("Close All");
run("Collect Garbage");
setBatchMode(false);