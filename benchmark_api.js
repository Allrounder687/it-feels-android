const BASE_URL = 'https://it-feels-proxy.cleverfox687.workers.dev';

async function benchmark(endpoint, name) {
    const start = performance.now();
    try {
        const res = await fetch(`${BASE_URL}${endpoint}`, {
            headers: { 'X-Feels-Secret': 'development_secret_123' }
        });
        const data = await res.json();
        const end = performance.now();
        const time = (end - start).toFixed(2);
        
        let count = 0;
        if (data.results) count = data.results.length;
        else if (data.songs) count = data.songs.length;
        else if (data.sections) count = data.sections.length;
        
        if (res.status !== 200) {
            console.log(`❌ [${name}] Failed! HTTP ${res.status}: ${JSON.stringify(data)}`);
            return;
        }
        
        console.log(`✅ [${name}] Success! Latency: ${time}ms | Items Returned: ${count}`);
    } catch (e) {
        console.log(`❌ [${name}] Failed! Error: ${e.message}`);
    }
}

async function runAll() {
    console.log("🚀 Starting Cloudflare API Benchmark...\n");
    
    // Warm-up request (Cloudflare cold starts can add ~50ms)
    await fetch(`${BASE_URL}/health`);
    
    await benchmark('/api/v1/native/home', 'Home Feed');
    await benchmark('/api/v1/native/search?query=arijit', 'Search: Arijit');
    await benchmark('/api/v1/native/search?query=taylor', 'Search: Taylor');
    await benchmark('/api/v1/native/search?query=bollywood', 'Search: Bollywood');
    await benchmark('/api/v1/native/search?query=lofi', 'Search: Lofi');
    
    console.log("\n🏁 Benchmark Complete!");
}

runAll();
