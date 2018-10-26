// simple macro to check DAPI spot with TrackMate
// Make sure TrackMate is open and image is calibrated to micron meter
// Should also have generated mask with ROI Manager open
roiNumber = getNumber("type a number of ROI:", 1);
roiManager("Select", roiNumber-1);
shrink = getNumber("shrink from edge (um):", 2.5);
run("Enlarge...", "enlarge=-"+shrink);
waitForUser("check LoG counter after preview:");
run("Make Band...", "band="+shrink);
waitForUser("check LoG counter after preview:");