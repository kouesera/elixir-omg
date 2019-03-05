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

defmodule OMG.Watcher.ExitProcessor.CompetitorInfo do
  @moduledoc """
  Represents the bulk of information about a competitor to an IFE.

  Internal stuff of `OMG.Watcher.ExitProcessor`
  """

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction

  # mapped by tx_hash
  defstruct [
    :tx,
    # TODO: what if someone does challenges once more but with another input?
    :competing_input_index,
    :competing_input_signature
  ]

  # NOTE: Although `Transaction.Signed` is used here, not all inputs will have signatures in this construct
  #       Still, we do use it, because it is formally correct - it is just not a valid transaction from the POV of
  #       the ledger
  @type t :: %__MODULE__{
          tx: Transaction.Signed.t(),
          competing_input_index: 0..3,
          competing_input_signature: Crypto.sig_t()
        }

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  def make_db_update({tx_hash, %__MODULE__{} = competitor}) do
    expected_fields = [:tx, :competing_input_index, :competing_input_signature]

    value = expected_fields |> Enum.reduce(%{}, fn key, acc -> Map.put_new(acc, key, Map.fetch!(competitor, key)) end)

    {:put, :competitor_info, {tx_hash, value}}
  end

  def from_db_kv({tx_hash, %__MODULE__{} = competitor}) do
    from_db_kv({tx_hash, Map.from_struct(competitor)})
  end

  def from_db_kv({tx_hash, competitor_map}) do
    expected_fields = %__MODULE__{} |> Map.from_struct() |> Map.keys()
    ^expected_fields = competitor_map |> Map.keys()

    {tx_hash, struct!(__MODULE__, competitor_map)}
  end

  def new(tx_bytes, competing_input_index, competing_input_signature) do
    with {:ok, raw_tx} <- Transaction.decode(tx_bytes) do
      {Transaction.hash(raw_tx),
       %__MODULE__{
         tx: %Transaction.Signed{
           raw_tx: raw_tx,
           sigs: [competing_input_signature]
         },
         competing_input_index: competing_input_index,
         competing_input_signature: competing_input_signature
       }}
    end
  end
end
