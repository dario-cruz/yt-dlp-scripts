const fs = require('fs');
const path = require('path');
const NodeID3 = require('node-id3');

const directory = './';
const files = fs.readdirSync(directory).filter(file => file.endsWith('.mp3'));

for (const file of files) {
    let newFile = file;
    let renameNeeded = false;
    let tagUpdateNeeded = false;
    
    // Check filename
    if (file.toLowerCase().includes(' - topic')) {
        // Case-insensitive replace for "- Topic" with nothing
        newFile = file.replace(/ - topic/gi, '');
        renameNeeded = true;
    }
    
    const filePath = path.join(directory, file);
    const tags = NodeID3.read(filePath);
    
    // Check tags (artist)
    let newArtist = tags.artist;
    if (newArtist && newArtist.toLowerCase().includes(' - topic')) {
        newArtist = newArtist.replace(/ - topic/gi, '');
        tagUpdateNeeded = true;
    }

    if (tagUpdateNeeded) {
        console.log(`Updating tags for ${file}: changing artist from "${tags.artist}" to "${newArtist}"`);
        const updatedTags = { ...tags, artist: newArtist };
        NodeID3.update(updatedTags, filePath);
    }
    
    if (renameNeeded) {
        const newFilePath = path.join(directory, newFile);
        console.log(`Renaming file: "${file}" -> "${newFile}"`);
        fs.renameSync(filePath, newFilePath);
    }
}
console.log('Finished checking and cleaning "- Topic" from filenames and tags.');
