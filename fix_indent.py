path = r"d:\coding\Echo Ai 2.0\lib\main.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# The _triggerFinalSpeech method lost its indentation because the previous
# _addToResponseBuffer closing brace was also missing proper indentation.
# Fix: ensure both methods are properly indented as class methods.

# Fix 1: _triggerFinalSpeech declaration missing "  " indent for class membership
old1 = "  }\r\nFuture<void> _triggerFinalSpeech() async {"
new1 = "  }\r\n\r\n  Future<void> _triggerFinalSpeech() async {"
content = content.replace(old1, new1)

# Fix 2: same with LF only
old2 = "  }\nFuture<void> _triggerFinalSpeech() async {"
new2 = "  }\n\n  Future<void> _triggerFinalSpeech() async {"
content = content.replace(old2, new2)

# Fix 3: Inner lines of _triggerFinalSpeech need 4-space indent (they're at 2)
# The method body currently has 2-space indent but by being top-level they look wrong.
# Actually the real issue is the method is not indented into the class.
# We need all lines inside _triggerFinalSpeech to remain as-is (they use "  " for class member body)
# The real error is the method declaration itself was not indented.
# Let's verify what we just did fixed it:
if "Future<void> _triggerFinalSpeech() async {" in content:
    print("WARNING: still unindented _triggerFinalSpeech found!")
else:
    print("_triggerFinalSpeech indentation fixed")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("done")
