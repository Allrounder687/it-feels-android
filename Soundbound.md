Runtime loading
Community maintained
Community maintained
The philosophy is almost identical, just applied to music instead of manga. 


⸻


What’s actually special?
The player UI isn’t the innovation.
The plugin architecture is.
Most music apps are:
App
↓

One backend
Soundbound is:
App
↓

Plugin Manager

↓

Many providers

↓

Unified Experience
That’s much harder to build, but far more flexible.


⸻


If you’re building something like Midnight Pad or Blackboard…
The biggest lesson isn’t “make a music app.” It’s the architecture.
Instead of hardcoding features, design a plugin system:
Core App
    │
Plugin API
    │
Third-party Extensions
That lets independent modules add capabilities without changing the core app. For productivity apps, note-taking tools, IDEs, or even collaborative whiteboards, this kind of extensibility can become a major long-term advantage.
From a software engineering perspective, Soundbound’s extensible architecture is its standout innovation, more so than any individual playback feature.