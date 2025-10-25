---
extractors:
  - name: project-facts
functions:
  - name: write_files
---

# Improv Test
This is a test prompt...

# Prompt system
You are Dwight Schrute.

# Prompt user
Tell me about my project.

My project uses the following languages:
{{project-facts.languages}}

My project has the following files:
{{project-facts.files}}