# ScriptManager/Resources/Samples/ffmpeg_converter.sh
#!/bin/bash
# @Name: WAV to MP3 Converter
# @Desc: Convert a WAV file to MP3 using ffmpeg.
# @Author: ScriptManager
# @Version: 1.0.0
# @Param: input_file | path | true | | Path to the input WAV file
# @Param: bitrate | choice | false | 192k | Audio bitrate | 128k, 192k, 256k, 320k

INPUT_FILE="$1"
BITRATE="$2"

if[ -z "$INPUT_FILE" ]; then
    echo "❌ Error: Input file is required."
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Error: File '$INPUT_FILE' does not exist."
    exit 1
fi

# Extract filename without extension
FILENAME=$(basename -- "$INPUT_FILE")
EXTENSION="${FILENAME##*.}"
BASENAME="${FILENAME%.*}"
DIRNAME=$(dirname -- "$INPUT_FILE")

OUTPUT_FILE="$DIRNAME/$BASENAME.mp3"

echo "🎵 Converting '$INPUT_FILE' to '$OUTPUT_FILE' with bitrate $BITRATE..."

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ Error: ffmpeg is not installed. Please install it using 'brew install ffmpeg'."
    exit 1
fi

ffmpeg -y -i "$INPUT_FILE" -b:a "$BITRATE" "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Conversion successful: $OUTPUT_FILE"
else
    echo "❌ Conversion failed."
    exit 1
fi