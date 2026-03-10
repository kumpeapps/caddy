# Development Container

This devcontainer provides a complete development environment for the Caddy Docker project.

## Features

### Included Tools

- **Docker-in-Docker**: Build and run Docker containers from within the devcontainer
- **Git**: Version control with latest Git
- **GitHub CLI**: Command-line interface for GitHub
- **Zsh with Oh My Zsh**: Enhanced shell experience

### VS Code Extensions

- **GitHub Copilot & Copilot Chat**: AI-powered code assistance
- **Git QuickOps**: Enhanced Git operations
- **Docker**: Docker container management
- **ShellCheck**: Shell script linting
- **Markdown Support**: Enhanced markdown editing and linting
- **Caddyfile Support**: Syntax highlighting for Caddyfile
- **Error Lens**: Inline error highlighting
- **Code Spell Checker**: Catch typos

## Getting Started

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Install [VS Code](https://code.visualstudio.com/)
3. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
4. Open this folder in VS Code
5. Click "Reopen in Container" when prompted (or use Command Palette: "Dev Containers: Reopen in Container")

## Building the Project

Once inside the devcontainer:

```bash
# Build the Caddy image
docker build -t caddy-custom .

# Run the container
docker run -d \
  -p 80:80 \
  -p 443:443 \
  -e ACME_EMAIL=test@example.com \
  -e CLOUDNS_AUTH_ID=your-id \
  -e CLOUDNS_AUTH_PASSWORD=your-password \
  -v $(pwd)/sites:/sites:ro \
  -v caddy_data:/data \
  -v caddy_config:/config \
  caddy-custom

# View logs
docker logs -f <container-id>
```

## Port Forwarding

The following ports are automatically forwarded:

- **80**: HTTP
- **443**: HTTPS
- **2019**: Caddy Admin API

## Tips

- Use GitHub Copilot Chat for code suggestions and questions
- Use Git QuickOps for quick Git operations
- Docker socket is mounted, so you can build and run containers
- ShellCheck will automatically lint your shell scripts
- Markdown files will be automatically formatted on save
