# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Mix.Tasks.Xomg.ChildChain.Start do
  @moduledoc """
    Contains mix.task to run the child chain server
  """

  use Mix.Task

  import XomgTasks.Utils

  @shortdoc "Start the child chain server. See Mix.Tasks.ChildChain"

  def run(args) do
    args
    |> generic_prepare_args()
    |> generic_run(:omg_api)
  end
end
