const BASE_URL = 'https://it-feels-proxy.cleverfox687.workers.dev';
const SECRET = 'development_secret_123';

// A massive master pool of artists and queries to randomly harvest from
const MASTER_POOL = [
    // Decades & Genres
    "2024 Global Hits", "Trending India 2024", "Top 50 Global", "Pop Hits", "Lofi Chill", "Workout Music",
    "90s Bollywood", "2000s Bollywood", "2010s Bollywood", "Punjabi Party", "Tamil Top 50", "Telugu Chartbusters",
    
    // A-Z Indian Artists (Subset)
    "A.R. Rahman", "Arijit Singh", "Anirudh Ravichander", "Alka Yagnik", "Atif Aslam", "Armaan Malik", "Amit Trivedi",
    "Badshah", "B Praak", "Bappi Lahiri", "Bhojpuri Hits", "Benny Dayal",
    "Chitra", "Clinton Cerejo",
    "Diljit Dosanjh", "Darshan Raval", "Devi Sri Prasad",
    "Gippy Grewal", "Guru Randhawa",
    "Harris Jayaraj", "Honey Singh", "Harrdy Sandhu", "Hariharan",
    "Ilayaraja", "Irfan",
    "Jubin Nautiyal", "Javed Ali", "Jonita Gandhi",
    "Kishore Kumar", "Kumar Sanu", "KK", "Kavita Krishnamurthy", "Kailash Kher", "Karthik", "Karan Aujla",
    "Lata Mangeshkar", "Lucky Ali",
    "Mohammed Rafi", "Mukesh", "Mithoon", "Mika Singh", "Mohit Chauhan", "M.M. Keeravani",
    "Neha Kakkar", "Neeti Mohan", "Nakash Aziz",
    "Palak Muchhal", "Pritam",
    "Rahat Fateh Ali Khan", "Roop Kumar Rathod",
    "Shreya Ghoshal", "Sonu Nigam", "Shaan", "Sukhwinder Singh", "Sunidhi Chauhan", "Sidhu Moose Wala", "Sid Sriram", "Shankar Mahadevan",
    "Tulsi Kumar", "Thaman S",
    "Udit Narayan",
    "Vishal Dadlani", "Vijay Prakash",
    "Yuvan Shankar Raja", "Yasser Desai",
    
    // A-Z Global Artists (Subset)
    "Adele", "Ariana Grande", "Avicii", "Alan Walker", "Arctic Monkeys",
    "Billie Eilish", "Beyonce", "Bruno Mars", "Backstreet Boys", "BTS",
    "Coldplay", "Celine Dion", "Charlie Puth", "Calvin Harris",
    "Drake", "Dua Lipa", "David Guetta",
    "Ed Sheeran", "Eminem", "Elton John", "Elvis Presley",
    "Frank Sinatra", "Fleetwood Mac",
    "Harry Styles", "Halsey",
    "Imagine Dragons",
    "Justin Bieber", "Jay-Z", "John Legend",
    "Katy Perry", "Kanye West", "Kendrick Lamar",
    "Lady Gaga", "Linkin Park", "Lana Del Rey",
    "Michael Jackson", "Madonna", "Miley Cyrus", "Maroon 5", "Morgan Wallen",
    "Nirvana", "Notorious B.I.G.",
    "Olivia Rodrigo", "One Direction",
    "Post Malone", "Pitbull", "Pink Floyd",
    "Queen",
    "Rihanna", "Red Hot Chili Peppers",
    "Selena Gomez", "Shawn Mendes", "Snoop Dogg", "Sia", "Shakira",
    "Taylor Swift", "The Weeknd", "The Beatles", "Tupac", "Travis Scott",
    "Usher", "U2",
    "Whitney Houston", "Wiz Khalifa",
    "Zayn"
];

// Pick 15 random items from the master pool
function getRandomChunk(size) {
    const shuffled = MASTER_POOL.sort(() => 0.5 - Math.random());
    return shuffled.slice(0, size);
}

async function runHarvester() {
    const queries = getRandomChunk(15);
    console.log(`\n==========================================`);
    console.log(`🤖 GitHub Actions Harvester Bot Awakened!`);
    console.log(`Starting automated daily extraction...`);
    console.log(`Targeting ${queries.length} random categories/artists.`);
    console.log(`==========================================\n`);
    
    let totalImported = 0;
    
    for (let i = 0; i < queries.length; i++) {
        const query = queries[i];
        console.log(`[${i+1}/${queries.length}] Harvesting: "${query}"...`);
        try {
            const res = await fetch(`${BASE_URL}/api/v1/native/seed/saavn`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Feels-Secret': SECRET,
                    'User-Agent': 'GitHub-Actions-Harvester-Bot/1.0'
                },
                body: JSON.stringify({ queries: [query], limitPerQuery: 100 })
            });
            const data = await res.json();
            if (data.success) {
                console.log(`   -> Successfully scraped and saved ${data.importedCount} new songs!`);
                console.log(`   -> Total DB Size: ${data.totalCatalogSize}`);
                totalImported += data.importedCount;
            } else {
                console.log(`   -> Warning:`, data);
            }
        } catch (e) {
            console.log(`   -> Network Error:`, e.message);
        }
        
        // Sleep for 2.5 seconds to bypass API rate limiting securely
        await new Promise(r => setTimeout(r, 2500));
    }
    
    console.log(`\n==========================================`);
    console.log(`🛑 Harvester Bot Going to Sleep...`);
    console.log(`Total new tracks secured this session: ${totalImported}`);
    console.log(`==========================================\n`);
}

runHarvester();
