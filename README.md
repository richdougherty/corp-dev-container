# corp-dev-container

A dev container image that's simple and easy to distribute in a
corporate environment - all you need is Docker.

Go to your project directory and start the container with:
```sh
eval "$(docker run --rm richdougherty/corp-dev-container:0.1.0 --run)"
```

## Features

- Bundles its own launch scripts - invoked when run with `--run`.
- Comes with a sensible dev image and dev tools.
- Use `mise` to install more.
- Automatically runs as the correct user, avoiding permissions problems.
- Mounts `.ssh`, `.gitconfig`, shared caches and other sensible files
  and folders.