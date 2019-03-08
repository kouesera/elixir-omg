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

defmodule OMG.Eth.Node do
  @moduledoc """
  Tracks state of local node (Geth only is supported)
  """

  @spec node_ready() :: :ok | {:error, :node_still_syncing | :node_not_listening}
  def node_ready do
    case Ethereumex.HttpClient.eth_syncing() do
      {:ok, false} -> :ok
      {:ok, _} -> {:error, :node_still_syncing}
      {:error, :econnrefused} -> {:error, :node_not_listening}
    end
  end

  @doc """
  Checks node syncing status, errors are treated as not synced.
  Returns:
  * false - node is synced
  * true  - node is still syncing.
  """
  @spec syncing?() :: boolean
  def syncing?, do: node_ready() != :ok
end
