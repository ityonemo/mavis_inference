import Type.Inference.Pipeline

defpipeline Type.BasicInference,
  [Type.SpecInference, Type.Inference, Type.NoInference]

# spin up the block cache
Type.Inference.BlockCache.start_link(nil)

Application.put_env(:mavis, :inference, Type.BasicInference)

ExUnit.start()
