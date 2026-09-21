<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/branding/ember-logo.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/branding/ember-logo-dark.svg">
    <img src="assets/branding/ember-logo-dark.svg" alt="Ember" width="300">
  </picture>
</p>

<p align="center">
  Ember is my personal Niri-focused UBlue image.<br>
  Built around how I like to use my desktop. Still a work in progress.
</p>

---

PRs are disabled as this is just for my own use. You're welcome to use it yourself, but it's highly opinionated and built around my preferences.

### Install

Install Bazzite GNOME with NVIDIA Open first. Once Ember's signed image is published, run this from your installed system:

```bash
curl -fsSLo rebase.sh https://raw.githubusercontent.com/Drostina/Ember/main/rebase.sh
bash rebase.sh
```

Reboot when it finishes. Bazzite handles installation; Ember adds my Niri packages. Extra Flatpaks are handled by my Niri install script.
