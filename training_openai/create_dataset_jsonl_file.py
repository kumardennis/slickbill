import json

# Open the text file with JSON content
with open('C:/source/slickbill/training_openai/supplier_dataset.txt', 'r') as infile:
    # Load the entire JSON content
    data = json.load(infile)

# Open the output JSONL file for writing
with open('C:/source/slickbill/training_openai/supplier_dataset.jsonl', 'w') as outfile:
    for item in data:
        # Write each JSON object as a single line
        outfile.write(json.dumps(item) + '\n')
