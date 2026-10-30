const fs = require('fs');
const path = require('path');
const NodeID3 = require('node-id3');
const Jimp = require('jimp'); // Make sure to use jimp@0.22.12

// This will process the directory where the script is run
const musicDir = process.cwd();

async function processFile(filePath) {
    const tags = NodeID3.read(filePath);
    
    if (tags && tags.image && tags.image.imageBuffer) {
        try {
            const imageBuffer = tags.image.imageBuffer;
            
            // Load image using Jimp
            const image = await Jimp.read(imageBuffer);
            
            // Auto crop borders (e.g. black bars or empty space)
            image.autocrop();
            
            // Check if it's perfectly 1:1, if not, crop to center square
            const width = image.bitmap.width;
            const height = image.bitmap.height;
            
            if (width !== height) {
                const size = Math.min(width, height);
                const x = (width - size) / 2;
                const y = (height - size) / 2;
                image.crop(x, y, size, size);
            }
            
            // Get processed image buffer
            const newImageBuffer = await image.getBufferAsync(Jimp.MIME_JPEG);
            
            // Update tags
            tags.image.imageBuffer = newImageBuffer;
            tags.image.mime = "image/jpeg";
            
            const success = NodeID3.update(tags, filePath);
            if (success) {
                console.log(`Successfully cropped cover art for: ${path.basename(filePath)}`);
            } else {
                console.log(`Failed to update cover art for: ${path.basename(filePath)}`);
            }
        } catch (e) {
            console.error(`Error processing image for ${path.basename(filePath)}:`, e.message);
        }
    }
}

async function walkDir(dir) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) {
            // Ignore node_modules
            if (file !== 'node_modules') {
                await walkDir(fullPath);
            }
        } else if (file.toLowerCase().endsWith('.mp3')) {
            await processFile(fullPath);
        }
    }
}

console.log(`Starting cover art crop process in ${musicDir}...`);
walkDir(musicDir)
    .then(() => console.log('Done!'))
    .catch(e => console.error(e));
