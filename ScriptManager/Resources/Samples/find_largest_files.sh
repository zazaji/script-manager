# ScriptManager/Resources/Samples/find_largest_files.sh
#!/bin/bash
# @Name: Find Largest Files
# @Desc: Find the largest files with a specific extension in a directory.
# @Author: ScriptManager
# @Version: 1.0.0
# @Param: target_dir | path | true | | Directory to search
# @Param: extension | string | true | txt | File extension (e.g., txt, log, mp4)
# @Param: count | string | false | 10 | Number of files to find

TARGET_DIR="$1"
EXTENSION="$2"
COUNT="${3:-10}"

if[ -z "$TARGET_DIR" ] || [ -z "$EXTENSION" ]; then
    echo "❌ Error: Target directory and extension are required."
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Error: Directory '$TARGET_DIR' does not exist."
    exit 1
fi

echo "🔍 Searching for top $COUNT largest '.$EXTENSION' files in '$TARGET_DIR'..."

find "$TARGET_DIR" -type f -name "*.$EXTENSION" -exec du -h {} + | sort -rh | head -n "$COUNT"

echo "✅ Search completed."