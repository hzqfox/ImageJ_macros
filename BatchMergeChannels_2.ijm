//#@ File (label = "Input directory", style = "directory") inputDir
/* 	Merge multi-channel images ZEN exported
 *  version 1.2.0
 *  2018.05.31
 *  author: Ziqiang Huang <Ziqiang.Huang@cruk.cam.ac.uk>
 */

 // Timing the start
start = getTime();


setBatchMode(true);



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
	targetFolder = checkFolder(input);
	if(targetFolder) {
		processFile(input);
	} else {			
		targetFolder = false;
		list = getFileList(input);
		list = Array.sort(list);
		for (i = 0; i < list.length; i++) {
			if(File.isDirectory(input + File.separator + list[i])) {
				dName = input + File.separator + list[i];
				print(dName);
				//targetFolder = false;
				targetFolder = checkFolder(dName);
				if(targetFolder)
					processFile(dName);
			}		
		}
	}
}

function checkFolder(input) {
	if (matches(input,".*channelMerged.*"))
		return false;
	list = getFileList(input);
	list = Array.sort(list);
	target = false;
	i = 0;
	while (target == false && i<list.length) {
		//currentFileName = list[i];
		if (matches(list[i],".*c1.*")) {
			target = true;
		}
		i += 1;
	}
	return target;
}


// fucntion to process all image files within a folder
function processFile(input) {

	fileList = getFileList(input);
	// Create output folder "channelMerged"
	outputDir = input + File.separator + "channelMerged";
	if (File.exists(outputDir)) 
		return;
	else	
		File.makeDirectory(outputDir);
	print("Merging files in folder: "+input);
	for (i=0; i<fileList.length; i++) {
		if (!endsWith(fileList[i],"/")) {
			currentFileName = fileList[i];
			//print("current File:"+currentFileName);
			if (matches(fileList[i],".*c1.*")) {
	
				cStringIdx = indexOf(currentFileName,"c1");
				preString = substring(currentFileName,0,cStringIdx);
				postString = substring(currentFileName,cStringIdx+2,lengthOf(currentFileName));
				numChannel = countNumChannel(input,preString,postString);
				if (i==0) {
					print(preString + postString);
				}
				else
					print("\\Update"+1+":" + preString + postString);
					
				mergeChannels(input,preString,postString,numChannel,outputDir);
			}
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
