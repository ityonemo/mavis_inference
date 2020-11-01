import Type.Inference.Pipeline

defpipeline Type.BasicInference,
  [Type.SpecInference, Type.Inference, Type.NoInference]

Application.put_env(:mavis, :inference, Type.BasicInference)

ExUnit.start()
