return function(program_name)
    return {
        usage= "Usage: " .. program_name .. " [OPTION]... [FILE]...",
        explanation= "Concatenate FILE(s) to standard output."
    }
end