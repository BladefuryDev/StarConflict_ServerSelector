import re
import sys

def validate(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Strip multi-line comments --[[ ... ]]
    content = re.sub(r'--\[\[.*?\]\]', '', content, flags=re.DOTALL)
    # Strip multi-line strings [[ ... ]]
    content = re.sub(r'\[\[.*?\]\]', '', content, flags=re.DOTALL)
    # Strip single line comments
    content = re.sub(r'--[^\n]*', '', content)
    # Strip string literals
    content = re.sub(r'"(\\.|[^"\\])*"', '""', content)
    content = re.sub(r"'(\\.|[^'\\])*'", "''", content)
    # Strip elseif ... then across lines
    content = re.sub(r'\belseif\b.*?\bthen\b', '', content, flags=re.DOTALL)

    lines = content.split('\n')
    stack = []
    
    # We will tokenize line by line to keep track of line numbers
    for line_no, line in enumerate(lines, 1):
        tokens = re.findall(r'\b(function|then|do|repeat|until|end)\b', line)
        for t in tokens:
            if t in ('function', 'then', 'do', 'repeat'):
                stack.append((t, line_no))
            elif t == 'until':
                if stack and stack[-1][0] == 'repeat':
                    stack.pop()
                else:
                    print(f"Error: unexpected 'until' at line {line_no}")
                    return False
            elif t == 'end':
                if stack and stack[-1][0] in ('function', 'then', 'do'):
                    stack.pop()
                else:
                    print(f"Error: unexpected 'end' at line {line_no}, current stack: {stack}")
                    return False

    if stack:
        print(f"Error: unclosed blocks at lines: {stack}")
        return False

    print("Success: all Lua blocks and delimiters are 100% matched and valid!")
    return True

if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else 'server_selector_mod.lua'
    if not validate(path):
        sys.exit(1)

