# SPDX-License-Identifier: GPL-3.0-or-later
import re


def native_body_literals(text):
    """Bounded literal expressions only; never evaluate arbitrary game code."""
    text=re.sub(r'@"(?:""|[^"])*"|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|/\*.*?\*/|//[^\n]*','',text,flags=re.S)
    number=r'(?:0x[\dA-Fa-f]+|\d+)'
    assignment=r'\bBody\s*(?:=>|=(?![=>]))\s*'
    literals=re.findall(assignment+r'('+number+r')\s*;',text)
    for group in re.findall(r'\bBody\s*=\s*Utility.RandomList\(([^)]*)\)',text):
        if re.fullmatch(r'\s*'+number+r'(?:\s*,\s*'+number+r')*\s*',group):
            literals+=re.findall(number,group)
    for pair in re.findall(assignment+r'[^;?]+\?\s*('+number+r')\s*:\s*('+number+r')\s*;',text):
        literals.extend(pair)
    literals+=re.findall(r':\s*base\(\s*('+number+r')\s*,\s*0x3[Ee][\dA-Fa-f]{2}\b',text)
    return {int(value,16) if value.lower().startswith('0x') else int(value) for value in literals}
