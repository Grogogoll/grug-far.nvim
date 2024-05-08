local M = {}

function M.appendResultsChunk(buf, context, data)
  -- add text
  local lastline = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, lastline, lastline, false, data.lines)

  -- add highlights
  for i = 1, #data.highlights do
    local highlight = data.highlights[i]
    for j = highlight.start_line, highlight.end_line do
      vim.api.nvim_buf_add_highlight(buf, context.namespace, highlight.hl, lastline + j,
        j == highlight.start_line and highlight.start_col or 0,
        j == highlight.end_line and highlight.end_col or -1)
    end
  end

  -- compute result locations based on highlights and add location marks
  -- those are used for actions like quickfix list and go to location
  local state = context.state
  local resultLocationByExtmarkId = state.resultLocationByExtmarkId
  local resultsLocations = state.resultsLocations
  local lastLocation = nil
  for i = 1, #data.highlights do
    local highlight = data.highlights[i]
    local hl = highlight.hl
    local line = data.lines[highlight.start_line + 1]

    if hl == 'GrugFarResultsPath' then
      state.resultsLastFilename = string.sub(line, highlight.start_col + 1, highlight.end_col + 1)

      local markId = vim.api.nvim_buf_set_extmark(buf, context.locationsNamespace, lastline + highlight.start_line, 0, {})
      resultLocationByExtmarkId[markId] = { filename = state.resultsLastFilename }
    elseif hl == 'GrugFarResultsLineNo' then
      -- omit ending ':'
      lastLocation = { filename = state.resultsLastFilename }
      table.insert(resultsLocations, lastLocation)
      local markId = vim.api.nvim_buf_set_extmark(buf, context.locationsNamespace, lastline + highlight.start_line, 0, {})
      resultLocationByExtmarkId[markId] = lastLocation

      lastLocation.lnum = tonumber(string.sub(line, highlight.start_col + 1, highlight.end_col))
    elseif hl == 'GrugFarResultsLineColumn' and lastLocation and not lastLocation.col then
      -- omit ending ':', use first match on that line
      lastLocation.col = tonumber(string.sub(line, highlight.start_col + 1, highlight.end_col))
    end
  end
end

-- note: row is zero-based
function M.getResultLocation(row, buf, context)
  local marks = vim.api.nvim_buf_get_extmarks(buf, context.locationsNamespace,
    { row, 0 }, { row, 0 }, { limit = 1 })
  if #marks > 0 then
    local markId = unpack(marks[1])
    return context.state.resultLocationByExtmarkId[markId]
  end

  return nil
end

function M.setError(buf, context, error)
  M.clear(buf, context)

  local startLine = context.state.headerRow + 1

  local err_lines = vim.split((error and #error > 0) and error or 'Unexpected error!', '\n')
  vim.api.nvim_buf_set_lines(buf, startLine, startLine, false, err_lines)

  for i = startLine, startLine + #err_lines do
    vim.api.nvim_buf_add_highlight(buf, context.namespace, 'DiagnosticError', i, 0, -1)
  end
end

function M.clear(buf, context)
  -- remove all lines after heading and add one blank line
  local headerRow = context.state.headerRow
  vim.api.nvim_buf_set_lines(buf, headerRow, -1, false, { "" })

  vim.api.nvim_buf_clear_namespace(buf, context.locationsNamespace, 0, -1)
  context.state.resultLocationByExtmarkId = {}
  context.state.resultsLocations = {}
  context.state.resultsLastFilename = nil
end

return M
