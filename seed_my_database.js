const BASE_URL = 'https://it-feels-proxy.cleverfox687.workers.dev';
const SECRET = 'development_secret_123';

const QUERIES = [
    // --- 1990s Bollywood & Global ---
    "90s Bollywood Romantic Hits",
    "Kumar Sanu Hits",
    "Udit Narayan",
    "Alka Yagnik",
    "A.R. Rahman 90s",
    "90s Pop Music Global",
    "Nirvana",
    "Michael Jackson 90s",
    "Backstreet Boys",
    "Spice Girls",
    "Britney Spears",

    // --- 2000s Bollywood & Global ---
    "2000s Bollywood Party Hits",
    "Sonu Nigam",
    "Shaan",
    "Sunidhi Chauhan",
    "KK Hits",
    "Himesh Reshammiya",
    "Eminem",
    "Linkin Park",
    "Coldplay",
    "Rihanna 2000s",
    "Beyonce",

    // --- 2010s Bollywood & Global ---
    "2010s Bollywood Hits",
    "Arijit Singh",
    "Shreya Ghoshal",
    "Badshah",
    "Neha Kakkar",
    "Atif Aslam",
    "Pritam",
    "Drake",
    "Justin Bieber",
    "Ed Sheeran",
    "Taylor Swift 2010s",
    "Ariana Grande",
    "The Weeknd",
    
    // --- 2020s Bollywood & Global (Present) ---
    "Trending Bollywood 2024",
    "Anirudh Ravichander",
    "Darshan Raval",
    "King",
    "Sidhu Moose Wala",
    "AP Dhillon",
    "Diljit Dosanjh",
    "Dua Lipa",
    "Billie Eilish",
    "Olivia Rodrigo",
    "Post Malone",
    "Morgan Wallen",
    
    // --- Massive Genres & Playlists ---
    "Global Top 50",
    "Viral Hits India",
    "Lofi Bollywood Chill",
    "Gym Workout Hits",
    "Punjabi Pop",
    "Top English Pop"
];

async function seedSequentially() {
    console.log(`Starting MASSIVE 3-Decade Seed to ${BASE_URL}...`);
    console.log(`Total Categories to Seed: ${QUERIES.length}`);
    
    let totalImported = 0;
    
    for (let i = 0; i < QUERIES.length; i++) {
        const query = QUERIES[i];
        console.log(`\n[${i+1}/${QUERIES.length}] Seeding: "${query}"...`);
        try {
            const res = await fetch(`${BASE_URL}/api/v1/native/seed/saavn`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Feels-Secret': SECRET,
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
                },
                // Fetching 30 top songs per category
                body: JSON.stringify({ queries: [query], limitPerQuery: 30 })
            });
            const data = await res.json();
            if (data.success) {
                console.log(`   -> Added ${data.importedCount} new unique songs.`);
                console.log(`   -> Total Catalog Size: ${data.totalCatalogSize}`);
                totalImported += data.importedCount;
            } else {
                console.log(`   -> Error:`, data);
            }
        } catch (e) {
            console.log(`   -> Request failed:`, e.message);
        }
        
        // Sleep for 1 second between requests to avoid overloading Saavn/Cloudflare
        await new Promise(r => setTimeout(r, 1000));
    }
    
    console.log(`\n🎉 MASSIVE SEED COMPLETE!`);
    console.log(`Successfully bulk imported ~${totalImported} new songs across 3 decades!`);
}

seedSequentially();
