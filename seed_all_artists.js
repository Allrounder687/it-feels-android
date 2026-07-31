const BASE_URL = 'https://it-feels-proxy.cleverfox687.workers.dev';
const SECRET = 'development_secret_123';

const ARTISTS = [
    // --- Bollywood & Indian Legends ---
    "A.R. Rahman", "Arijit Singh", "Shreya Ghoshal", "Kishore Kumar", "Lata Mangeshkar",
    "Mohammed Rafi", "Mukesh", "Asha Bhosle", "R.D. Burman", "Kalyanji Anandji",
    "Laxmikant Pyarelal", "Bappi Lahiri", "Anu Malik", "Jatin-Lalit", "Shankar Ehsaan Loy",
    "Pritam", "Vishal-Shekhar", "Amit Trivedi", "Salim-Sulaiman", "Mithoon",
    "Sonu Nigam", "Shaan", "Udit Narayan", "Kumar Sanu", "KK",
    "Mohit Chauhan", "Javed Ali", "Sukhwinder Singh", "Kailash Kher", "Rahat Fateh Ali Khan",
    "Atif Aslam", "Ali Zafar", "Armaan Malik", "Darshan Raval", "Jubin Nautiyal",
    "Sunidhi Chauhan", "Alka Yagnik", "Kavita Krishnamurthy", "Anuradha Paudwal", "Sadhana Sargam",
    "Neha Kakkar", "Tulsi Kumar", "Palak Muchhal", "Jonita Gandhi", "Neeti Mohan",
    "Badshah", "Honey Singh", "Guru Randhawa", "Hardy Sandhu", "Mika Singh",
    "Diljit Dosanjh", "Sidhu Moose Wala", "AP Dhillon", "Karan Aujla", "B Praak",
    "Ammy Virk", "Harrdy Sandhu", "Sharry Mann", "Gippy Grewal", "Jassi Gill",

    // --- South Indian Cinema ---
    "Anirudh Ravichander", "Harris Jayaraj", "Yuvan Shankar Raja", "Ilayaraja", "S.P. Balasubrahmanyam",
    "K.S. Chithra", "Sid Sriram", "Thaman S", "Devi Sri Prasad", "M.M. Keeravani",
    "Vijay Prakash", "Armaan Malik Telugu", "Haricharan", "Karthik", "Hariharan",

    // --- Global Pop & Modern Icons ---
    "Taylor Swift", "The Weeknd", "Drake", "Ed Sheeran", "Justin Bieber",
    "Ariana Grande", "Billie Eilish", "Dua Lipa", "Post Malone", "Olivia Rodrigo",
    "Harry Styles", "Bruno Mars", "Adele", "Rihanna", "Beyonce",
    "Katy Perry", "Lady Gaga", "Miley Cyrus", "Selena Gomez", "Shawn Mendes",

    // --- Global Legends & Classics ---
    "Michael Jackson", "The Beatles", "Queen", "Elvis Presley", "Madonna",
    "Elton John", "Whitney Houston", "Celine Dion", "Mariah Carey", "Frank Sinatra",
    "Nirvana", "Coldplay", "Linkin Park", "Eminem", "Tupac",
    "Notorious B.I.G.", "Snoop Dogg", "Dr. Dre", "Jay-Z", "Kanye West"
];

async function seedSequentially() {
    console.log(`Starting MASSIVE Artist Collection Seed to ${BASE_URL}...`);
    console.log(`Total Artists to Seed: ${ARTISTS.length}`);
    
    let totalImported = 0;
    
    for (let i = 0; i < ARTISTS.length; i++) {
        const artist = ARTISTS[i];
        console.log(`\n[${i+1}/${ARTISTS.length}] Seeding Artist: "${artist}"...`);
        try {
            const res = await fetch(`${BASE_URL}/api/v1/native/seed/saavn`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Feels-Secret': SECRET,
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
                },
                // Requesting up to 100 tracks per artist to get their core collection
                body: JSON.stringify({ queries: [artist], limitPerQuery: 100 })
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
        
        // Sleep for 1.5 seconds between heavy requests
        await new Promise(r => setTimeout(r, 1500));
    }
    
    console.log(`\n🎉 MASSIVE ARTIST SEED COMPLETE!`);
    console.log(`Successfully bulk imported ~${totalImported} new songs from ${ARTISTS.length} global and regional artists!`);
}

seedSequentially();
