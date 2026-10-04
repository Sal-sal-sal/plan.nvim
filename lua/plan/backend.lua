local config = require("plan.config")
local M = {}
local warned = false

function M.path()
  if config.options.binary then
    return vim.fn.expand(config.options.binary)
  end
  local suffix = vim.fn.has("win32") == 1 and ".exe" or ""
  for _, dir in ipairs({ "/bin/", "/target/release/" }) do
    local path = config.root .. dir .. "plan-nvim" .. suffix
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
  return vim.fn.exepath("plan-nvim")
end

local function decode(result)
  if result.code ~= 0 then
    return nil,
      (result.stderr ~= "" and result.stderr) or "Rust engine exited with code " .. result.code
  end
  local ok, response =
    pcall(vim.json.decode, result.stdout, { luanil = { object = true, array = true } })
  if not ok or type(response) ~= "table" then
    return nil, "Rust engine returned invalid JSON"
  end
  if response.error then
    return nil, response.error
  end
  return response
end

local function missing()
  if not warned then
    warned = true
    vim.notify(
      "plan.nvim: Rust engine missing. Run :PlanBuild or set opts.binary.",
      vim.log.levels.WARN
    )
  end
end

function M.request(request, callback)
  local path = M.path()
  if path == "" or vim.fn.executable(path) ~= 1 then
    missing()
    return nil
  end
  local options = { text = true, stdin = vim.json.encode(request) .. "\n", timeout = 2000 }
  if callback then
    vim.system({ path }, options, function(result)
      vim.schedule(function()
        local response, error = decode(result)
        callback(response, error)
      end)
    end)
    return nil
  end
  local response, error = decode(vim.system({ path }, options):wait())
  if error then
    vim.notify("plan.nvim: " .. error, vim.log.levels.ERROR)
  end
  return response
end

function M.build()
  if vim.fn.executable("cargo") ~= 1 then
    vim.notify(
      "plan.nvim: install Rust/Cargo or use a release binary (opts.binary).",
      vim.log.levels.ERROR
    )
    return
  end
  vim.notify("plan.nvim: building Rust engine...")
  vim.system({ "cargo", "build", "--release", "--locked", "--target-dir", "target" }, {
    cwd = config.root,
    text = true,
  }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("plan.nvim: build failed\n" .. result.stderr, vim.log.levels.ERROR)
        return
      end
      warned = false
      vim.notify("plan.nvim: Rust engine ready")
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].filetype == "plan" then
          require("plan.render").refresh(buf)
        end
      end
    end)
  end)
end

return M
