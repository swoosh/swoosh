ExUnit.start()
ExUnit.configure(exclude: :integration)

Application.ensure_all_started(:bypass)
