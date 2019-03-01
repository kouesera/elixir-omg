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

defmodule OMG.API.Fees do
  @moduledoc """
  Transaction's fee validation functions
  """

  alias OMG.API.{Crypto, Utxo}
  alias OMG.API.State.Transaction
  alias Poison

  require Utxo

  @type fee_spec_t() :: %{token: Crypto.address_t(), flat_fee: non_neg_integer}
  @type token_fee_t() :: %{Crypto.address_t() => non_neg_integer}

  @doc """
  Parses provided json string to token-fee map and returns the map together with possible parsing errors
  """
  @spec parse_file_content(binary()) :: {list({:error, atom()}), token_fee_t()}
  def parse_file_content(file_content) do
    {:ok, json} = Poison.decode(file_content)

    {errors, token_fee_map, _} =
      json
      |> Enum.map(&parse_fee_spec/1)
      |> Enum.reduce({[], %{}, 1}, &spec_reducer/2)

    {Enum.reverse(errors), token_fee_map}
  end

  @doc """
  Checks whether transaction's funds cover the fee
  """
  @spec covered?(map(), map(), token_fee_t()) :: boolean()
  def covered?(input_amounts, output_amounts, fees) do
    for {input_currency, input_amount} <- Map.to_list(input_amounts) do
      # fee is implicit - it's the difference between funds owned and spend
      implicit_paid_fee = input_amount - Map.get(output_amounts, input_currency, 0)

      case Map.get(fees, input_currency) do
        nil -> false
        fee -> fee <= implicit_paid_fee
      end
    end
    |> Enum.any?()
  end

  @doc """
  Returns fees for particular transaction
  """
  @spec for_tx(Transaction.Recovered.t(), token_fee_t()) :: token_fee_t()
  def for_tx(
        %Transaction.Recovered{
          signed_tx: %Transaction.Signed{raw_tx: raw_tx}
        } = recovered_tx,
        fee_map
      ) do
    if is_merge_transaction?(recovered_tx) do
      # To make transaction fee free, zero-fee for transaction's currency needs to be explicitly returned.
      currency = raw_tx |> Transaction.get_currencies() |> hd()
      %{currency => 0}
    else
      # TODO: reducing fees to output currencies only is incorrect, let's deffer until fees get large
      fee_map
    end
  end

  defp parse_fee_spec(%{"flat_fee" => fee, "token" => token}) do
    # defensive code against user input
    with {:ok, fee} <- validate_fee(fee),
         {:ok, addr} <- Crypto.decode_address(token) do
      %{token: addr, flat_fee: fee}
    end
  end

  defp parse_fee_spec(_), do: {:error, :invalid_fee_spec}

  defp validate_fee(fee) when is_integer(fee) and fee >= 0, do: {:ok, fee}
  defp validate_fee(_fee), do: {:error, :invalid_fee}

  defp spec_reducer(fee_spec, {errors, token_fee_map, spec_index}) do
    case fee_spec do
      # most errors can be detected parsing particular record
      {:error, _} = error ->
        {[{error, spec_index} | errors], token_fee_map, spec_index + 1}

      # checks whether token was specified before
      %{token: token, flat_fee: fee} ->
        if Map.has_key?(token_fee_map, token),
          do: {[{{:error, :duplicate_token}, spec_index} | errors], token_fee_map, spec_index + 1},
          else: {errors, Map.put(token_fee_map, token, fee), spec_index + 1}
    end
  end

  defp is_merge_transaction?(recovered_tx) do
    [
      &has_less_outputs_than_inputs?/1,
      &has_single_currency?/1,
      &has_same_account?/1
    ]
    |> Enum.all?(fn predicate -> predicate.(recovered_tx) end)
  end

  @empty_input Utxo.position(0, 0, 0)
  @empty_output %{owner: OMG.Eth.zero_address(), currency: OMG.Eth.RootChain.eth_pseudo_address(), amount: 0}

  defp has_same_account?(%Transaction.Recovered{
         signed_tx: %Transaction.Signed{raw_tx: raw_tx},
         spenders: spenders
       }) do
    raw_tx
    |> Transaction.get_outputs()
    |> Enum.reject(&(@empty_output == &1))
    |> Enum.map(& &1.owner)
    |> Enum.concat(spenders)
    |> single?()
  end

  defp has_single_currency?(%Transaction.Recovered{
         signed_tx: %Transaction.Signed{raw_tx: raw_tx}
       }) do
    raw_tx
    |> Transaction.get_outputs()
    |> Enum.reject(&(@empty_output == &1))
    |> Enum.map(& &1.currency)
    |> single?()
  end

  defp has_less_outputs_than_inputs?(%Transaction.Recovered{
         signed_tx: %Transaction.Signed{raw_tx: raw_tx}
       }) do
    # we need to filter out placeholders
    inputs =
      Transaction.get_inputs(raw_tx)
      |> Enum.reject(&(@empty_input == &1))

    outputs =
      Transaction.get_outputs(raw_tx)
      |> Enum.reject(&(@empty_output == &1))

    has_less_outputs_than_inputs?(inputs, outputs)
  end

  defp has_less_outputs_than_inputs?(inputs, outputs), do: length(inputs) >= 1 and length(inputs) > length(outputs)

  defp single?(list), do: 1 == list |> Enum.dedup() |> length()
end
