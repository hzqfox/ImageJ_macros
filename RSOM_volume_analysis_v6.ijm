/**   
 * This is a ImageJ(FIJI) macro plugin for the analysis of blood vessel diameters
 * from images acquired from Raster Scanning Optoacoustic Mesoscopy (RSOM) system.
 * It developed for the Bohndiek lab at the CRUK-CI.
 * To use this plugin, RSOM images should be first exported as Tiff image stack.
 * 
 * This plugin will need two other ImageJ plugins to be installed to Fiji/plugins 
 * folder prior to regular usage:
 * 		Voxel Counter (https://imagej.nih.gov/ij/plugins/voxel-counter.html)
 * 			author: Wayne Rasband (wsr@nih.gov)
 * 		Local Thickness (https://imagej.net/Local_Thickness)
 * 			author: Bob Dougherty
 * 			"Computing Local Thickness of 3D Structures with ImageJ."
 * 			Microsc Microanal 13(Suppl 2), 2007
 * 		3D binary interpolate (https://github.com/mcib3d/mcib3d-plugins/
 * 				blob/master/src/main/java/mcib_plugins/BinaryInterpolator.java)
 * 			author: Thomas Boudier & Jean Ollion
 * 			!NOTE! It is very important to not have this plugin through 3D suite
 * 			update site, or even on github. They load Binary_Interpolator.java
 * 			instead of BinaryInterpolator.java which cause weired interpolation
 * 			behavior.
 * 
 * The plugin will perform background subtraction, intensity thresholding, and
 * median filter smoothing, which each parameter can be modified by the user, to 
 * generate a binary mask image stack. In the mask, value 255 (as for 8-bit image) 
 * represents signal (blood vessel), and 0 represents noise or background.
 * Based on the binary mask, it will then extract object (connected-component) and
 * calculate structure local thickness (blood vessel diameter). This results in two 
 * new image stacks contain objects and diameter information respectively: object_map 
 * and diameter map. In addition it will extract statistical information out of the
 * object and diameter maps into spreadsheet format. All these results will be saved to
 * a result folder parallelly nested with the input image stack on local machine.
 * An execution log will also be generated with each run, to keep track of processing and
 * for debugging.
 * 
 * v1.6
 * 2018.09.18
 * @author Ziqiang Huang <Ziqiang.Huang@cruk.cam.ac.uk   
 */ 

	/* 
	 *  generic dialog to get initial parameters from user
	 */
	requires("1.46f");
	Dialog.create("RSOM vessel analysis");
	Dialog.addNumber("Background subtraction radius:", 10);
	Dialog.addChoice("Thresholding method:", newArray("Otsu",
	"Minimum","Moments","IsoData","Percentile","Shanbhag","Triangle","Manual"));
	Dialog.addNumber("Mask median filter size:", 2.5);
	Dialog.addCheckbox("Open file on disk", true);
	Dialog.addCheckbox("Use selected area instead of whole image", true);
	Dialog.addCheckbox("Export mask as ROI", true);
	Dialog.addCheckbox("Export object map", true);
	Dialog.addCheckbox("Export diameter map", true);  	  	 
	
	html = "<html>"
	 +"<h2>help</h2>"
	 +"RSOM blood vessel volume analysis"
	 +"ImageJ macro script"
	 +"Choose either a folder containing the stack or an open image stack"
	 +"If require analysis performed within a selection,"
	 +"draw the selection first";
	Dialog.addHelp(html);
	Dialog.show();
	
	radius = Dialog.getNumber();
	method = Dialog.getChoice();
	md_filter_size = Dialog.getNumber();
	
	getFileOnDisk = Dialog.getCheckbox();
	getSelection = Dialog.getCheckbox();
	do_ROI = Dialog.getCheckbox();
	do_objMap = Dialog.getCheckbox();
	do_diameterMap = Dialog.getCheckbox();


	/*
	 * Global variables
	 */
	var imgFolder;
	var resultFolder;
	var voxelSize = newArray(20,20,4);
	var bounds = newArray(-1,-1);
	
	/*
	 * plugin main body
	 */
	 // get starting time
	timeString = getDateTime();
	start = getTime();
	// get RSOM image stack
	imageNumber = getImageStack(getFileOnDisk);
	imgName = getTitle();
	// calibrate image if necessary
	voxelSize = checkCalibration(imageNumber);
	// subtract background
	if (radius!=0) {
		run("Subtract Background...", "rolling="+radius+" stack");
	}
	// threshold image
	if (method == "Manual") {
		manualThreshold(imageNumber,nSlices);
	} else {
		setAutoThreshold(method+" dark stack");
		getThreshold(bounds[0],bounds[1]);
		setOption("BlackBackground", true);
		run("Convert to Mask", "method="+method+" background=Dark black");
	}
	// suppose to be image id of the binary mask, need debug
	ID = getImageID();
	// smooth binary image with median filter
	if (md_filter_size!=0) {
		run("Median...", "radius="+md_filter_size+" stack");
	}
	// get 3D selection
	imageNumber = getImageID();
	if (getSelection==true) {
		setBatchMode(false);
		run("ROI Manager...");
		selPath = getSelection3D(imageNumber,getSelection);
		setBatchMode(true);
	} else {
		selPath = getSelection3D(imageNumber,getSelection);
	}
	// save binary mask
	maskFileName = imgName + "_mask";
	run("Select None");
	saveAs("ZIP", resultFolder + File.separator + maskFileName);
	id_binMap = getImageID();
	// get ROI
	if (do_ROI) {
		run("Analyze Particles...", "clear include add stack");
		roiPath = resultFolder + File.separator + imgName + "_Roiset.zip";
		if (roiManager("count")==0) {
			print("No ROI identified, check threshold setting.");
			return;
		}
		roiManager("Save", roiPath);
		roiManager("reset");
	}
	// get object map
	run("Select None");
	if (do_objMap) {
		selectImage(id_binMap);
		run("Connected Components Labeling", "connectivity=26 type=[16 bits]");
		objMapImage = imgName + "_objectMap";
		saveAs("Tiff", resultFolder + File.separator + objMapImage + ".tiff");
		id_objMap = getImageID();
	}
	// get diameter map
	run("Select None");
	if (do_diameterMap) {
		selectImage(id_binMap);
		run("Local Thickness (masked, calibrated, silent)");
		locThkImage = imgName + "_DiameterMap";
		saveAs("Tiff", resultFolder + File.separator + locThkImage + ".tiff");
		id_diaMap = getImageID();
	}
	// use ROIs, diameter-map and object-map to create diameter measurements
	getResults(roiPath,selPath,id_binMap,id_objMap,id_diaMap,resultFolder);
	// close ROI manager and images, clean up memory
	roiManager("reset");	close("ROI Manager");	close("Results");
	close("*_objectMap*");	close("*_DiameterMap*");	close("*_mask*");
	run("Collect Garbage");
	setBatchMode(false);
	// log script runtime
	end = getTime()-start;
	logPath = resultFolder + File.separator + "execution_log.csv";
	getExecLog(timeString,end,logPath);
	print("Script run time total duration: " + end/1000 + " seconds");

	/* 
	 *  Functions
	 *  getImageStack(getFile)
	 *  getActiveImage()
	 *  checkCalibration(imageID)
	 *  manualThreshold(imageID,nZ)
	 *  getSelection3D(imageID,getSelection)
	 *  getResults(objROI,selROI,id_objMap,id_diaMap,resultFolder)
	 *  getSliceResult(selROI,id_binMap)
	 *  getRoiResult(nSelection,objROI,id_objMap,col_ID,col_obj,col_area,col_dia_mean,col_dia_min,col_dia_max,resultRoiPath)
	 *  getObjResult(nSelection,col_obj,col_area,col_dia_mean,col_dia_min,col_dia_max)
	 *  getHisto(id_diaMap,histPath)
	 *  getExecLog()
	 *  getDateTime()
	 */
	function getImageStack(getFile) {
		// note imgFolder and resultFolder are global variables!
		setBatchMode(true);	
		if (getFile==true) {
			//setBatchMode(true);
			inputFile = File.openDialog("Select image file:");
			open(inputFile);
			if (nSlices==1) {
				close();
				run("Image Sequence...", "open=["+inputFile +"] sort");
				currentFolder = File.getParent(inputFile);
				imgFolder = File.getParent(currentFolder);
			} else {
				imgFolder = File.getParent(inputFile);
			}
			imageNumber = getImageID();
		} else {
			imageNumber = getActiveImage();
			if (imageNumber==0) exit("No active image.");
			else selectImage(imageNumber);	
			imgFolder = getInfo("image.directory");
			// active image without saved to disk
			if (imgFolder == "") {
				print("Can not retrive local path of selected image stack.");
				imgFolder = getDirectory("Choose folder to save analysis result: ");
			} else {
				// if active image is image sequence, move up one level 
				if (getInfo("image.filename")=="") imgFolder = File.getParent(imgFolder);
			}
		}
		selectImage(imageNumber);
		imgName = getTitle();
		idx = lastIndexOf(imgName,".");
		if (idx>=0) imgName = substring(imgName,0,idx); // image name without extension
		resultFolder = imgFolder + File.separator + imgName + "_result";
		if (!File.exists(resultFolder)) File.makeDirectory(resultFolder);
		setBatchMode(false);
		return imageNumber;
	}

	function getActiveImage() {
		if (nImages==0) return 0;
		if (nImages==1) return 1;
		idString = "";
		for (i=0;i<nImages;i++) { 
	        selectImage(i+1);
	        idString = idString + d2s(i+1,0) + ": " + getTitle() + "\n";
		}
		showMessage("active images", idString);
		return getNumber("select which image to process", 1);
	}

	function checkCalibration(imageID) {
		// default calibration
		x_default = 20; y_default = 20; z_default = 4;
		selectImage(imageID);
		getVoxelSize(xV,yV,zV,unit);
		if (unit=="pixels") {
			print("image appears to be not calibrated");
			getDimensions(xD,yD,cD,zD,tD);
			if (xD!=yD) {
				Dialog.create("calibrate image");
				Dialog.addString("unit:", "micron");
				Dialog.addNumber("pixel width(x):", 20);
				Dialog.addNumber("pixel height(y):", 4);
				Dialog.addNumber("voxel depth(z):", 20);
				Dialog.show();
				unit = Dialog.getString();
				x_default = Dialog.getNumber();
				y_default = Dialog.getNumber();;
				z_default = Dialog.getNumber();
			} else { unit="micron"; }
			setVoxelSize(x_default,y_default,z_default,unit);	
		} else {
			x_default = xV;	y_default = yV; z_default = zV;
		}
		// return voxel size x, y, z
		vSize = newArray(x_default,y_default,z_default);
		print("image voxel size: x:" + x_default + " y:" + y_default
				+ " z:" + z_default + " unit:" + unit);
		return vSize;
	}
	
	function manualThreshold(imageID,nZ) {
		setBatchMode(false);
		run("Threshold...");
		title = "Manual Thresholding";
		msg = "Use the \"Threshold\" tool to adjust the threshold;\n"
			+ "Tick \"Stack histogram\";\nWhen finished, don't click"
			+ "\"Apply\", click \"OK\" here instead.";
		waitForUser(title, msg);
		selectImage(imageID);
		imgName = getTitle();
		getThreshold(bounds[0], bounds[1]);
		if (bounds[0]==-1) exit("Threshold was not set");
		// use the same lower and upper bound for all slices in the stack
		setBatchMode(true);
		setThreshold(bounds[0], bounds[1]);
		setOption("BlackBackground", true);
		run("Convert to Mask", "background=Dark black stack");
		selectWindow("Threshold");
		run("Close");
	}

	function getSelection3D(imageID,getSelection) {
		selectImage(imageID);
		if (roiManager("count") != 0) {
			roiManager("Deselect");
			roiManager("Delete");
		}
		if (getSelection == false) {
			for (i=0; i<nSlices; i++) {
				setSlice(i+1);
				run("Select All");
				roiManager("Add");
			}
			selectPath = resultFolder + File.separator + imgName + "_selection3D.zip";
			roiManager("Save", selectPath);
			// clear ROI manager and return
			roiManager("reset");
			return selectPath;
		}
		setBatchMode(false);
		waitForUser("Draw selection on slices and add to ROI Manager\n, when finished click OK to proceed.");
		setBatchMode(true);
		// create temporary mask stack to store ROIs
		imgName = getTitle();
		maskName = imgName + "_3D_mask";
		newImage(maskName, "8-bit black", getWidth(), getHeight(), nSlices);
		selectWindow(maskName);	
		nSelection = roiManager("count");
		setForegroundColor(255, 255, 255);
		for (i = 0; i < nSelection; i++) {
			roiManager("select", i);
			run("Fill", "slice");
		}
		run("Select None");
		run("3D Binary Interpolate");
		// fill ROI Manager with all interpolated ROIs
		sliceList = newArray(nSlices);
		for (i=0; i<nSlices; i++)
			sliceList[i] = i+1;
		nSelection = roiManager("count");
		for (i = 0; i < nSelection; i++) {
			roiManager("select", i);
			SN = getSliceNumber();
			sliceList[SN-1] = 0;
		}	
		for (i=0; i<sliceList.length; i++) {
			//print(sliceList[i]);
			if (sliceList[i]!=0) {
				setSlice(sliceList[i]);
				run("Create Selection");
				run("Make Inverse");
				getStatistics(area,mean);
				if (area*mean != 0)
					roiManager("Add");
			}
		}
		roiManager("sort");
		close(maskName);
		// clear region outside ROIs in the original stack
		selectImage(imageID);
		roiManager("Select", 0);	RoiStartSlice = getSliceNumber();
		nSelection = roiManager("count");
		roiManager("Select", nSelection-1);	RoiEndSlice = getSliceNumber();
		for (i = 1; i < RoiStartSlice; i++) {
			setSlice(i);
			run("Select All");
			run("Clear", "slice");
		}
		for (i = RoiEndSlice; i < nSlices; i++) {
			setSlice(i+1);
			run("Select All");
			run("Clear", "slice");
		}
		for (i = 0; i < nSelection; i++) {
			roiManager("select", i);
			run("Clear Outside", "slice");
		}
		// save interpolated 3D selection as ROI set
		selectPath = resultFolder + File.separator + imgName + "_selection3D.zip";
		roiManager("Save", selectPath);
		// clear ROI manager and return
		roiManager("reset");
		return selectPath;
	}

	
	function getResults(objROI,selROI,id_binMap,id_objMap,id_diaMap,resultFolder) {
		
		resultSlicePath = resultFolder + File.separator + "result_slice-wise.csv";
		resultRoiPath = resultFolder + File.separator + "result_ROI-wise.csv";
		resultObjPath = resultFolder + File.separator + "result_object-wise.csv";
		histPath = resultFolder + File.separator + "result_histogram.jpg";
		run("Clear Results");
		roiManager("reset");	roiManager("Open", objROI);
		nSelection = roiManager("count");	col_ID = newArray(nSelection);	col_area = newArray(nSelection);
		col_obj = newArray(nSelection);
		col_dia_mean = newArray(nSelection);
		col_dia_min = newArray(nSelection);
		col_dia_max = newArray(nSelection);
		
		getSliceResult(selROI,id_binMap,voxelSize,resultSlicePath);
		getRoiResult(nSelection,objROI,id_objMap,col_ID,col_obj,col_area,col_dia_mean,col_dia_min,col_dia_max,resultRoiPath);
		getObjResult(nSelection,col_obj,col_area,col_dia_mean,col_dia_min,col_dia_max,voxelSize,resultObjPath);
		getHisto(id_diaMap,histPath);
	}
	
	function getSliceResult(selROI,id_binMap,voxelSize,resultSlicePath) {
		run("Clear Results");
		run("Set Measurements...", " redirect=None decimal=3");
		selectImage(id_binMap);
		getDimensions(x, y, c, z, f);
		roiManager("reset");	roiManager("Open", selROI);
		nROI = roiManager("count");
		col_slice = newArray(nROI);
		col_vox = newArray(nROI);	col_area = newArray(nROI);
		col_areafrac = newArray(nROI);
		pxSize = voxelSize[0]*voxelSize[1]; vxSize = pxSize*voxelSize[2];
		for (i = 0; i < nROI; i++) {
			roiManager("Select", i);
			col_slice[i] = getSliceNumber();
			getStatistics(area, mean);
			col_area[i] = area;
			col_vox[i] = area*mean/pxSize/255;
			col_areafrac[i] = mean/255*100;
		}
		for (i = 0; i < nROI; i++) {
			setResult("slice number", i, col_slice[i]);
			setResult("thresholded voxel count", i, col_vox[i]);
			setResult("ROI area(µm^2)", i , col_area[i]);
			setResult("thresholded area fraction(%)", i, col_areafrac[i]);
		}
		updateResults;
		saveAs("Results", resultSlicePath);
		totalROIArea = 0;	totalThresVox = 0;	
		for (i=0;i<nROI;i++){ 
	 		totalROIArea += col_area[i]/400;
	 		totalThresVox += col_vox[i];
		}
		// construct summary information
		summaryString = '\n' + "Summary:\n";
		calString = ",Voxel size:," + d2s(voxelSize[0],0) + "*"
					+ d2s(voxelSize[1],0) + "*" + d2s(voxelSize[2],0)
					+ ",micron^3\n";
				
		stackString = ",stack voxel number:," + d2s(x*y*z,0) + '\n'
					+ ",stack volume," 
					+ d2s(x*y*z*vxSize,0) + ",micron^3\n";
		roiString = ",ROI voxel number:," + d2s(totalROIArea,0) + '\n'
					+ ",ROI volume," 
					+ d2s(totalROIArea*vxSize,0) + ",micron^3\n";	
		vxString = ",thresholded voxel number:," + d2s(totalThresVox,0) + '\n'
					+ ",thresholded voxel volume," 
					+ d2s(totalThresVox*vxSize,0) + ",micron^3\n";
		fracString = ",ROI fraction:,"	+ d2s(totalROIArea/x/y/z*100,3)
					+ ",%" + '\n'
					+ ",thresholded voxel fraction:,"
					+ d2s(totalThresVox/x/y/z*100,3) + ",%" + '\n'
					+ ",thresholded voxel to ROI fraction:,"
					+ d2s(totalThresVox/totalROIArea*100,3) + ",%\n";
		File.append(summaryString+calString+stackString+roiString+vxString+fracString,resultSlicePath);
		run("Clear Results");
	}
	
	function getRoiResult(nSelection,objROI,id_objMap,col_ID,col_obj,col_area,col_dia_mean,col_dia_min,col_dia_max,resultRoiPath) {
	
		roiManager("reset");	roiManager("Open", objROI);
		// 1st measure
		run("Set Measurements...", "area mean redirect=None decimal=3");
		selectImage(id_objMap);
		roiManager("Deselect");	roiManager("Measure");
		selectWindow("Results");
		result1 = getInfo("window.contents");
		rowData = split(result1,'\n'); rowData = Array.slice(rowData,1);
		for (r=0; r<nSelection; r++) {
			cellData = split(rowData[r],'\t');
			col_ID[r] = call("ij.plugin.frame.RoiManager.getName", r);
			col_area[r] = parseInt(cellData[1]);
			col_obj[r] = parseInt(cellData[2]);
		}
		run("Clear Results");
		//	2nd measure
		run("Set Measurements...", "area mean min redirect=None decimal=3");
		selectImage(id_diaMap);
		roiManager("Deselect");	roiManager("Measure");
		selectWindow("Results");
		result2 = getInfo("window.contents");
		rowData = split(result2,'\n'); rowData = Array.slice(rowData,1);
		for (r=0; r<nSelection; r++) {
			cellData = split(rowData[r],'\t');
			col_dia_mean[r] = parseInt(cellData[2]);
			col_dia_min[r] = parseInt(cellData[3]);
			col_dia_max[r] = parseInt(cellData[4]);
		}
		run("Clear Results");
		// sum results up
		for (i = 0; i < nSelection; i++) {
			setResult("ROI-ID", i, col_ID[i]);
			setResult("area(µm)", i, col_area[i]);
			setResult("object-ID", i , col_obj[i]);
			setResult("diameter mean(µm^2)", i, col_dia_mean[i]);
			setResult("diameter min(µm)", i, col_dia_min[i]);
			setResult("diameter max(µm)", i, col_dia_max[i]);
		}
		updateResults;
		saveAs("Results", resultRoiPath);
		run("Clear Results");
	}
	
	function getObjResult(nSelection,col_obj,col_area,col_dia_mean,col_dia_min,col_dia_max,voxelSize,resultObjPath) {
		run("Set Measurements...", "area mean min redirect=None decimal=3");
		rankPos = Array.rankPositions(col_obj);
		Array.getStatistics(col_obj, min, objSize);
		pxSize = voxelSize[0]*voxelSize[1];	vxSize = pxSize*voxelSize[2];
		col_obj_ID = newArray(objSize);	col_vol = newArray(objSize);	col_vol_sum = newArray(objSize);
		col_vol_mean = newArray(objSize);	col_vol_min = newArray(objSize);	col_vol_max = newArray(objSize);
		objID = 0;	col_pxSum = 0;
		for (i = 0; i < nSelection; i++) {
			// original index before sorting
			j = rankPos[i];
			currentObjID = col_obj[j];
			col_pxSum = col_area[j]/pxSize;
			if (currentObjID != objID) {
				objID += 1;
				col_obj_ID[objID-1] = objID;
				col_vol[objID-1] = col_pxSum*vxSize;
				col_vol_sum[objID-1] = col_dia_mean[j]*col_pxSum;
				col_vol_min[objID-1] = col_dia_min[j];
				col_vol_max[objID-1] = col_dia_max[j];
				col_vol_mean[objID-1] = col_dia_mean[j];
			} else {
				col_vol[objID-1] += col_pxSum*vxSize;
				col_vol_sum[objID-1] += col_dia_mean[j]*col_pxSum;
				col_vol_min[objID-1] = minOf(col_vol_min[objID-1], col_dia_min[j]);
				col_vol_max[objID-1] = maxOf(col_vol_max[objID-1], col_dia_max[j]);
				col_vol_mean[objID-1] = col_vol_sum[objID-1]/col_vol[objID-1]*vxSize;
			}
		}
		for (i = 0; i < objSize; i++) {
			setResult("Obj-ID", i, col_obj_ID[i]);
			setResult("volume(µm^3)", i, col_vol[i]);
			setResult("diameter mean", i, col_vol_mean[i]);
			setResult("diameter min", i, col_vol_min[i]);
			setResult("diameter max", i, col_vol_max[i]);
		}
		updateResults;
		saveAs("Results", resultObjPath);
		run("Clear Results");
	}

	function getHisto(id_diaMap,histPath) {
		selectImage(id_diaMap);
		run("Histogram", "bins=13 x_min=0 x_max=260 y_max=[] stack");
		run("Capture Image");
		saveAs("Jpeg", histPath);
		close("*Histogram*");
	}

	function getExecLog(timeString,duration,logPath) {
		if (getSelection==true)
			selString = "YES";
		else
			selString = "NO";
		titleString = '\n' + "Execution at:\n" + timeString + '\n';
		parseString = "image folder:," + imgFolder + '\n'
					+ "image stack name:," + imgName + '\n'
					+ "background subtraction radius:," + d2s(radius,1) + ",pixel" + '\n'
					+ "thresholding method:," +  method + '\n'
					+ "thresholding value:," + d2s(bounds[0],3) + ',' + d2s(bounds[1],3) + '\n'
					+ "median filter raidus:," + d2s(md_filter_size,1) + ",pixel" + '\n'
					+ "selected area (ROI) instead of whole stack:," + selString + '\n';
		durationString = "script run time total duration:," + d2s(duration/1000,0) + ",second" + '\n';	
		File.append(titleString+parseString+durationString,logPath);			
	}
	
	function getDateTime() {
		MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
		DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		TimeString ="Date:,"+DayNames[dayOfWeek]+" ";
		if (dayOfMonth<10) {TimeString = TimeString+"0";}
		TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+"\nTime:,";
		if (hour<10) {TimeString = TimeString+"0";}
		TimeString = TimeString+hour+":";
		if (minute<10) {TimeString = TimeString+"0";}
		TimeString = TimeString+minute+":";
		if (second<10) {TimeString = TimeString+"0";}
		TimeString = TimeString+second;
		return TimeString;
	}