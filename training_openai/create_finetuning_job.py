import openai

'Training file id: file-inpYdAB9NrEkGOww3MzfiWjH'

training_file_id = "file-inpYdAB9NrEkGOww3MzfiWjH"

api_key = "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"

openai.api_key = api_key

#Create Fine-Tuning Job
suffix_name = "slickbills-bot"

response = openai.FineTuningJob.create(
    api_key=api_key,
    training_file=training_file_id,
    model="gpt-3.5-turbo-0613",
    suffix=suffix_name,
)

job_id = response["id"]

print(response)