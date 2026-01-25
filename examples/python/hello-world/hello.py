#!/usr/bin/env python3
"""
Simple Hello World demonstration in Python.

This example demonstrates:
- Basic Python script structure
- Function definition
- Main guard
- Print statements
"""

def greet(name="World"):
    """
    Greet someone by name.
    
    Args:
        name (str): The name to greet. Defaults to "World".
    
    Returns:
        str: The greeting message.
    """
    return f"Hello, {name}!"


def main():
    """Main function to run the greeting."""
    print(greet())
    print(greet("Mahesh"))
    print(greet("Developer"))


if __name__ == "__main__":
    main()
