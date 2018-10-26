//#@ File (label = "Input directory", style = "directory") inputDir
/* 	Merge multi-channel images ZEN exported
 *  version 1.2.0
 *  2018.05.31
 *  author: Ziqiang Huang <Ziqiang.Huang@cruk.cam.ac.uk>
 */

 // Timing the start
start = getTime();


setBatchMode(true);

// Create output folder "channelMerged"
outputDir = inputDir + File.separator + "channelMerged";
if (!File.exists(outputDir)) 
	File.makeDirectory(outputDir);

// Process image files in the input directory
print("\\Clear");

processFolder(inputDir);
//processFile(inputDir);

setBatchMode(false);
run("Collect Garbage");
// timing the end
print("Script ends at: " + (getTime()-start)/1000 + " seconds.");

// function to process folders
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i]);
	}
}


// fucntion to process all image files within a folder
function processFile(input) {

	fileList = getFileList(input);
	print("Merging files in folder: "+input);
	for (i=0; i<fileList.length; i++) {
	
		currentFileName = fileList[i];
		if (matches(fileList[i],".*c1.*")) {

			cStringIdx = indexOf(currentFileName,"c1");
			preString = substring(currentFileName,0,cStringIdx);
			postString = substring(currentFileName,cStringIdx+2,lengthOf(currentFileName));
			numChannel = countNumChannel(inputDir,preString,postString);
			if (i==0) {
				print(preString + postString);
			}
			else
				print("\\Update"+1+":" + preString + postString);
			mergeChannels(inputDir,preString,postString,numChannel,outputDir);
		}
	}
}




function countNumChannel(parentFolder,preString,postString) {
	numC = 0;
	i = 0;
	while (i<100) {
		filename = parentFolder+File.separator+preString+"c"+d2s(i,0)+postString;
		if (File.exists(filename)) {
			numC += 1;
		}
		i++;
	}	
	return (numC);
}

function mergeChannels(parentFolder,preString,postString,numChannel,outputFolder) {
	commandOption = "";
	for (i=1; i<=numChannel; i++) {
		img = parentFolder+File.separator+preString+"c"+d2s(i,0)+postString;
		open(img);
		title=getTitle();
		commandOption = commandOption+"c"+d2s(i,0)+"=["+title+"] ";
		}
	commandOption = commandOption + " create";	
	run("Merge Channels...", commandOption);
	outputFile = outputFolder + File.separator + preString+postString;
    saveAs("tiff", outputFile);
    close();
}
