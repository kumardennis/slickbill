import openai


openai.api_key = "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"


#Upload data for training
training_file_name = 'C:/source/slickbill/training_openai/supplier_dataset.jsonl'

training_response = openai.File.create(
    file=open(training_file_name, "rb"), purpose="fine-tune"
)
training_file_id = training_response["id"]

#Gives training file id
print("Training file id:", training_file_id)