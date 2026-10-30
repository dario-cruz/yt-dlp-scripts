const fs = require('fs');
const path = require('path');
const NodeID3 = require('node-id3');

const directory = './';

async function fetchGenre(query) {
    try {
        const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&entity=song&limit=1`;
        const response = await fetch(url);
        const data = await response.json();
        if (data.results && data.results.length > 0) {
            return data.results[0].primaryGenreName;
        }
    } catch (error) {
        console.error(`Error fetching genre for query ${query}:`, error.message);
    }
    return null;
}

async function processFiles() {
    const files = fs.readdirSync(directory).filter(file => file.endsWith('.mp3'));
    
    for (const file of files) {
        const filePath = path.join(directory, file);
        console.log(`\nProcessing: ${file}`);
        
        // Read tags
        const tags = NodeID3.read(filePath);
        let title = tags.title;
        let artist = tags.artist;
        let genre = tags.genre;
        
        console.log(`Current Tags - Title: ${title}, Artist: ${artist}, Genre: ${genre}`);
        
        if (!title || !artist) {
            // Attempt to parse from filename
            const basename = path.parse(file).name;
            // Format often is: "Title - Artist.mp3" or "Title (feat. someone) - Artist.mp3"
            const parts = basename.split(' - ');
            if (parts.length >= 2) {
                if (!title) title = parts[0].trim();
                if (!artist) artist = parts[parts.length - 1].trim();
            } else {
                if (!title) title = basename.trim();
            }
        }
        
        const query = `${title || ''} ${artist || ''}`.trim();
        if (!query) {
            console.log(`Could not determine query for ${file}. Skipping.`);
            continue;
        }
        
        console.log(`Searching for: ${query}`);
        const foundGenre = await fetchGenre(query);
        
        if (foundGenre) {
            console.log(`Found genre: ${foundGenre}`);
            if (genre !== foundGenre) {
                const updatedTags = { ...tags, genre: foundGenre };
                const success = NodeID3.update(updatedTags, filePath);
                if (success) {
                    console.log(`Updated genre to: ${foundGenre}`);
                } else {
                    console.error(`Failed to update genre for ${file}`);
                }
            } else {
                console.log(`Genre is already correct (${genre}). No update needed.`);
            }
        } else {
            console.log(`No genre found for ${query}`);
        }
        
        // Add a small delay to avoid rate limiting
        await new Promise(r => setTimeout(r, 500));
    }
    console.log('\nFinished processing all files.');
}

processFiles();
