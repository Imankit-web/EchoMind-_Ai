"""
Root cause: The Python script searched for the anchored text starting with the @override/build method
but the file uses mixed CRLF/LF line endings; the anchor matched at char 45547 inside the 
_addToResponseBuffer method (second occurrence of a similar pattern), which cut the class at the wrong place.

Strategy: 
1. Read the file
2. Find the LAST occurrence of `  }\n` that precedes `  // ─── Mini AppBar` (our marker)
3. Verify everything between line ~751 (class open) and that point is valid class body
4. Ensure build/helper methods are inside the class braces
"""

path = r"d:\coding\Echo Ai 2.0\lib\main.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Marker we inserted
MARKER = "  // ─── Mini AppBar"
marker_idx = content.find(MARKER)
print(f"Marker at: {marker_idx}")

# Check what's right before the marker
before = content[marker_idx-60:marker_idx]
print(f"Text before marker:\n{repr(before)}")

# The class _ResponseSelectionScreenState should contain everything.
# Find its open brace
class_open = "class _ResponseSelectionScreenState extends State<ResponseSelectionScreen> {"
class_idx = content.find(class_open)
print(f"Class open at: {class_idx}")

# Find what closes the class just before our marker
# The class closing brace should be the last "}\n" before our marker
# But actually the class was accidentally closed by an extra } somewhere
# Let's count braces from class_idx to marker_idx
segment = content[class_idx:marker_idx]
depth = 0
last_close_pos = -1
for i, ch in enumerate(segment):
    if ch == '{':
        depth += 1
    elif ch == '}':
        depth -= 1
        if depth == 0:
            last_close_pos = class_idx + i
            print(f"Class CLOSED at absolute pos {last_close_pos} (relative {i})")
            # Show context
            print(f"Context: {repr(content[last_close_pos-30:last_close_pos+50])}")
            break

# If the class was closed before the marker, we need to remove that closing brace
# and put it after _getOptionColor closing
if last_close_pos != -1 and last_close_pos < marker_idx:
    print("\nFIX NEEDED: removing premature class closing brace")
    surrounding = content[last_close_pos-2:last_close_pos+5]
    print(f"Premature close context: {repr(surrounding)}")
    # Remove the lone closing brace and any surrounding blank lines
    content = content[:last_close_pos] + content[last_close_pos+1:]
    print("Removed premature class close")

# Now find _getOptionColor method (last method before helpers)
# and ensure there's a proper closing brace for the class after it
get_option_color = "  Color _getOptionColor(String opt) => const Color(0xFF00C2FF);\n}"
if get_option_color not in content:
    get_option_color2 = "  Color _getOptionColor(String opt) => const Color(0xFF00C2FF);\r\n}"
    if get_option_color2 in content:
        print("Found _getOptionColor (CRLF)")
    else:
        print("WARNING: _getOptionColor not found, checking...")
        idx2 = content.find("_getOptionColor")
        if idx2 != -1:
            print(f"Found at {idx2}: {repr(content[idx2:idx2+80])}")
else:
    print("_getOptionColor closing brace looks correct")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("\nSaved. Run flutter analyze again.")
