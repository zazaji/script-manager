# ScriptManager/Resources/Templates/template.py
#!/usr/bin/env python3
# @Name: New Python Script
# @Desc: A sample script to demonstrate auto UI generation.
# @Author: You
# @Version: 1.0.0
# @Param: name | string | true | World | Who to greet
# @Param: verbose | bool | false | false | Enable verbose output

import sys

def main():
    args = sys.argv[1:]
    name = "World"
    verbose = False
    
    for arg in args:
        if arg == "--verbose":
            verbose = True
        else:
            name = arg
            
    if verbose:
        print("Verbose mode enabled.")
        
    print(f"Hello, {name}!")

if __name__ == "__main__":
    main()