return {
    first_time="%s is running for the first time, installing...",
    usage= "usage:\t cube <operation> [...]\n" ..
        "operations:\n" ..
        "\tcube {-h --help}\n" ..
        "\tcube {-v --version}\n" ..
        "\tcube {-s --search}\t<package(s)>\n" ..
        "\tcube {-i --install}\t<package(s)\n" ..
        "\tcube {-r --remove}\t<package(s)\n" ..
        "\tcube {-u --update}\n" ..
        "\tcube {-c --clean}\n",
    help= "Show help",
    version= "Show version",
    search= "Search for local and remote packages",
    install= "Install pacakges if not installed or outdated",
    remove= "Remove packages and its orphan dependencies",
    update= "Updates this program",
    clean= "Remove all orphan dependencies",
    download_error= "Download error",
    fetching_info="Fetching info for %s",
    already_newest="%s is already the newest version (%v)",
    already_satisfied= "Dependency %s is already satisfied (%v)",
    not_installed="%s is not installed",
    installing= "Installing %s",
    installing_dependencies= "Installing dependencies",
    not_found= "%s not found",
    user= "User",
    remote= "Remote"
}