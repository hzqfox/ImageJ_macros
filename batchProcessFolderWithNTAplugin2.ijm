/*
 * 
 * version 1.1.0
 * 2018.05.25
 */
#@ File (label = "Input directory", style = "directory") input
list = getFileList(input);
list = Array.sort(list);

// Timing the start
start = getTime();
currentTime = getTime();
print("Script starts at: ");
printTime();

// scan input directory including subdirectories
// to run NuclearTissueAnalysis plugin on all
// images with mask found
scanFolder(input);

// Timing the end
print("Script ends at: ");
printTime();
print("Script run time total duration: ");
duration = getTime()-start;
printDuration(duration);


// function to scan foler "input" for the right image data folder and file 
// to run Jeremy's plugin NuclearTissueAnalysis
function scanFolder(input) {

	// get all files and folders of input directory
	list = getFileList(input);
	list = Array.sort(list);

	// loop through all files and folders of input directory
	for (i = 0; i < list.length; i++) {

		// check if current file "list[i]" is a directory
		if(File.isDirectory(input + File.separator + list[i])) {			
			
			// check if folder "channelMerged" can be found at current location
			cMFolder = input + File.separator + "channelMerged" + File.separator;
			if (File.exists(cMFolder)) {
				
				// when found the "channelMerged" folder, process the images inside this folder
				// first check if the raw data folder and mask folder have been created
				dataFolderExist = false;
				maskFolderExist = false;
				rawFolderExist = false;
				maskDir = cMFolder + "mask" + File.separator;
				rawDir1 = cMFolder + "raw" + File.separator;
				rawDir2 = cMFolder + "raw_data" + File.separator;
				
				if (File.exists(maskDir)) {
					maskFolderExist = true;
				}
				if (File.exists(rawDir1)) {
					rawFolderExist = true;	
				} else if (File.exists(rawDir2)) {
					// rename the raw data file folder into the right name
					File.rename(rawDir2,rawDir1);
					rawFolderExist = true;
				}
				if (maskFolderExist && rawFolderExist) {
					dataFolderExist = true;
				}
				
				// if the "raw" folder and "mask" folder haven't been created,
				// first create these two folders within "channelMerged" folder
				if (dataFolderExist == false) {
					// create and prepare data folder
					makeSubDir(cMFolder);		
				}
				// when both "raw" and "mask" folder exist, run the plugin
				
				// Timing current time point
				durationNow = getTime()-currentTime;
				print("Script has been running for: ");
				printDuration(durationNow);
				currentTime = getTime();
				
				// run plugin at current folder
				print("Processing folder: " + cMFolder);
				runNTAplugin(cMFolder);
			}
			// if the folder "channelMerged" can not be found, keep scanning all subfolders at current location
			else {
				scanFolder(input + File.separator + list[i]);
			}
		}			
	}
}

// function to create the subfolder "raw" and "mask" and move image files into them
function makeSubDir(input) {

	list = getFileList(input);
	list = Array.sort(list);
	
	rawDir = input + "raw" + File.separator;
	maskDir = input + "mask" + File.separator;
	File.makeDirectory(rawDir);
	File.makeDirectory(maskDir);
	status = 0;
	for (i = 0; i < list.length; i++) {
		if (matches(list[i], ".*tif.*")) {
			oldFilePath = input + File.separator + list[i];
			if (matches(list[i],".*Predictions.*")) {
				//oldMaskFilePath = input + File.separator + list[i];
				// rename .tiff to .tif
				// fileNameWithExtension = list[i] 
				maskFileName = substring(list[i],0,lengthOf(list[i])-28);
				maskFileName = maskFileName + "_Object Predictions.tif";
				//maskFileName = substring(list[i], 0, lengthOf(list[i])-1);
				newMaskFilePath = maskDir + File.separator + maskFileName;
				status = File.rename(oldFilePath,newMaskFilePath);
			}
			else {
				newRawFilePath = rawDir + File.separator + list[i];
				status = File.rename(oldFilePath,newRawFilePath);
			}
		}
	}	
}

// function to run plugin "Nuclear Tissue Analysis v1.1.0
// with "input/raw" and "input/mask" as the input data folders,
// it also save the result table as "input/Output.csv".
function runNTAplugin(input) {
	// Do the processing here by adding your own code.
	// Leave the print statements until things work, then remove them.
	rawDir = input + File.separator + "raw";
	maskDir = input + File.separator + "mask";
	// NTA v1.1.1
	//run("Nuclear Tissue Analysis", "raw=["+rawDir+"] object=["+maskDir+"] radius=1.125 quality=40 define=1.5 specify=1 specify_0=10");
	// NTA v1.1.2
	run("Nuclear Tissue Analysis", "raw=["+rawDir+"] object=["+maskDir+"] image=0.2405002 specify=1 radius=0.75 quality=6 define=1.5 specify_0=1 specify_1=0");
	selectWindow("Output");
	//resultFilePath = input+ File.separator + "Output.csv";
	saveAs("Results", input+ File.separator + "Output.csv");
	run("Close");
}

// function to print the current time to Log window
function printTime() {
	getDateAndTime(year, mon, dayOfW, day, hr, min, sec, msec);
	TimeString = "" + year + "." + mon+1 + ".";
	if (day < 10) {TimeString = TimeString+"0";}
	TimeString = TimeString + day + " - ";
	if (hr < 10) {TimeString = TimeString+"0";}
	TimeString = TimeString + hr + ":";
	if (min < 10) {TimeString = TimeString+"0";}
	TimeString = TimeString + min + ":";
	if (sec < 10) {TimeString = TimeString+"0";}
	TimeString = TimeString + sec + "." + msec;
	print(TimeString);
}

// function to print duration, it takes numbers of millisecond as input
function printDuration(duration) {
	hrs = mins = secs = msecs = 0;
	hrs = floor(duration/60/60/1000); duration = duration - hrs*60*60*1000;
	mins = floor(duration/60/1000); duration = duration - mins*60*1000;
	secs = floor(duration/1000); duration = duration - secs*1000;
	msecs = duration;
	durationString = "" + hrs + " hours " + mins + " minutes " + secs + "." + msecs + " seconds";
	print(durationString);
}