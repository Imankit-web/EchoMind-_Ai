path = r"d:\coding\Echo Ai 2.0\lib\main.dart"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Truncate to everything BEFORE line 1728
# Python lists are 0-indexed, so line 1728 is index 1727.
# We want to keep lines 0 to 1726 (which is 1727 lines).
if len(lines) > 1727:
    trimmed_lines = lines[:1727]
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(trimmed_lines)
    print(f"File truncated from {len(lines)} to {len(trimmed_lines)} lines.")
else:
    print("File is already shorter than 1727 lines.")
