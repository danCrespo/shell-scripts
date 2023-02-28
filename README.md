# Shell-scripts

___Korn shell (ksh), Bourne shell (sh), Bourne again shell (bash) scripts.___

_This project is still under construction_

---

### Description.
Collection of scripts for ___Bourne shell___, ___Korn shell___ and ___Bourne Again shell___ (mostly you will find for bash).

The purpose of this collection is to share simple scripts that execute basic tasks for the administration of `UNIX-based` 
operating systems _(Linux distros like `Ubuntu`, `SentOS`, `Debian`, etc...)_. Tasks such as installation, configuration, 
file processing, bash completion, certificate creation, among others and some extras.

---

### Structure.

The collection is divided into different directories from which the content can be inferred given its name (or is it intended).
In each directory you will find a `README.md` file in which its content, use and necessary information will be described in greater
detail _(if it does not already contain a README.md, it will soon)_.

**Note:** The number of directories will increase over time.

The directories and their existing content up to now are listed and described below:

- __bash_completion:__   
    Contains the script to autocomplete bash commands in your shell.  
    You will find two scripts, `bash_completion` for Ubuntu and `bash_completion` for MacOS,
    as well as a directory with completions for some commands and a script to integrate completions
    that don't exist in your bash completion directory _(usually under `bash-completion.d/`)_.
    
- __crypto:__  
    Basic commands and scripts to get hash or certificate information, encrypt or decrypt whatever
    you need to keep secure, and related tasks.
    
- __flavors_specs:__  
    Some templates that can be customized and used in your scripts.
    
- __kubernetes:__  
    Tasks related to installing and deploying  `Kubernetes` clusters, such as:  
    - Automated installation of dependencies and binaries.
    - Creation of certificates (CA and TLS/authentication, these __will be self-signed__).
    - kubectl cheat sheets.
    - Adding workers to your control plane
