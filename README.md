# Cursor Project Template

A simple template to help you start new projects with Cursor AI and development containers.

## Prerequisites

Make sure you have these installed on your computer:

- **Cursor** (or Visual Studio Code) - your code editor
- **Dev Container extension** - adds container support to your editor
- **Docker Desktop** - must be installed and running

## Getting Started

### 1. Create Your Project
1. Copy this entire folder to a new location on your computer
2. Rename the folder to whatever you want to call your project
3. Open the folder in Cursor or VS Code

### 2. Start the Development Environment
1. Press `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (Mac) to open the command palette
2. Type "Dev Containers: Rebuild Container" and press Enter
3. Wait for the setup to complete (this may take a few minutes the first time)

![Dev Container Setup](.docs/images/devcontainer.png)

### 3. Tell AI About Your Project
1. Open the file `.docs/Initial_Prompt.md`
2. Write down what you want to build and any specific requirements
3. The AI will help you set up and develop your project 
4. Ask the Agent chat to read the project folder and ask any clarifying questions or design implementations to get started
5. Follow the prompts

## Important Information

## MCP Usage

- If you want to use MCP's (the MCP servers must live in docker desktop)

![Docker Desktop MCP Setup](.docs/images/DDmcps.png)

- Add the docker version MCP client into the .cursor/mcp.json file

![Docker Desktop MCP Client Setup](.docs/images/DDclientmcp.png)



**Don't delete or move these folders** - they're needed for the template to work:
- `.docs/` - project documentation and AI prompts
- `.cursor/` - Cursor-specific settings
- `.devcontainer/` - development container configuration
- `.tests/` - testing setup

These folders are automatically hidden from version control, so you don't need to worry about them.

## Important Note

**If you're using Visual Studio Code instead of Cursor**: Change the `.cursor/` folder name to `.vscode/` for proper VS Code integration.

## Troubleshooting

If something isn't working:

1. **Docker Desktop**: Make sure it's running (and has been run at least once before)
2. **Extensions**: Check that the Dev Container extension is installed in your editor
3. **Container Issues**: Try rebuilding the container from the command palette
4. **Still Stuck?**: Check the Docker Desktop logs or restart your editor

---





