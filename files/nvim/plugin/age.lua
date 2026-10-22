-- Transparently edit age-encrypted files (*.age) with the age CLI.
--
-- Decrypts with the identity in ~/.config/age/keys.txt (or $AGE_IDENTITY).
-- Re-encrypts to the recipients in the nearest recipient.txt above the file
-- (secrets/recipient.txt in the dotfiles), falling back to the identity's own
-- recipient. Armor is kept as found; new files are armored. The plaintext
-- never touches disk: no swap, undo or backup files, and shada is disabled
-- once an encrypted file has been opened, as registers would leak into it.
-- Not a plugin spec: lazy.nvim sources plugin/ in the config dir at startup.

local identity = vim.env.AGE_IDENTITY
  or vim.fs.joinpath(vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME, ".config"), "age", "keys.txt")
local armor_header = "-----BEGIN AGE ENCRYPTED FILE-----"

-- age's first stderr line; the rest is its "report errors at" footer.
local function stderr(res)
  return vim.split(vim.trim(res.stderr or ""), "\n")[1]
end

local function err(msg)
  vim.notify("age: " .. msg, vim.log.levels.ERROR)
end

local function protect(buf)
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false
  vim.o.shada = ""
end

local function set_filetype(buf, path)
  local ft = vim.filetype.match({ buf = buf, filename = path:gsub("%.age$", "") })
  if ft then
    vim.bo[buf].filetype = ft
  end
end

local function read(args)
  local buf, path = args.buf, vim.fn.fnamemodify(args.match, ":p")
  protect(buf)
  local f = io.open(path, "rb")
  if not f then
    vim.b[buf].age_armor = true
    set_filetype(buf, path)
    return
  end
  local head = f:read(#armor_header)
  f:close()
  vim.b[buf].age_armor = head == armor_header

  local res = vim.system({ "age", "--decrypt", "--identity", identity, path }, { text = false }):wait()
  if res.code ~= 0 then
    -- Keep :w from overwriting the ciphertext with an empty buffer.
    vim.b[buf].age_failed = true
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    err("decryption failed: " .. stderr(res))
    return
  end

  local text = res.stdout or ""
  vim.bo[buf].eol = text:sub(-1) == "\n"
  if vim.bo[buf].eol then
    text = text:sub(1, -2)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[buf].modified = false
  set_filetype(buf, path)
end

local function find_recipients(path)
  return vim.fs.find("recipient.txt", { path = vim.fs.dirname(path), upward = true, type = "file" })[1]
end

local function write(args)
  local buf, path = args.buf, vim.fn.fnamemodify(args.match, ":p")
  if vim.b[buf].age_failed then
    err("refusing to write: " .. path .. " was not decrypted")
    return
  end

  local recipients = { "--recipients-file", find_recipients(path) }
  if not recipients[2] then
    local res = vim.system({ "age-keygen", "-y", identity }):wait()
    if res.code ~= 0 then
      err("no recipient.txt found and cannot read " .. identity .. ": " .. stderr(res))
      return
    end
    recipients = { "--recipient", vim.trim(res.stdout) }
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  if vim.bo[buf].eol or vim.bo[buf].fixeol then
    text = text .. "\n"
  end

  -- Encrypt next to the target and rename, so a failure leaves it intact.
  local tmp = path .. ".tmp" .. vim.fn.getpid()
  local cmd = { "age", "--encrypt", "--output", tmp }
  if vim.b[buf].age_armor ~= false then
    table.insert(cmd, "--armor")
  end
  vim.list_extend(cmd, recipients)
  local res = vim.system(cmd, { stdin = text }):wait()
  if res.code ~= 0 then
    os.remove(tmp)
    err("encryption failed: " .. stderr(res))
    return
  end
  local ok, rename_err = os.rename(tmp, path)
  if not ok then
    os.remove(tmp)
    err(rename_err)
    return
  end
  if path == vim.api.nvim_buf_get_name(buf) then
    vim.bo[buf].modified = false
  end
  vim.notify(("age: wrote %s (%d lines)"):format(vim.fn.fnamemodify(path, ":~:."), #lines))
end

local group = vim.api.nvim_create_augroup("age_encrypted", { clear = true })
vim.api.nvim_create_autocmd("BufReadCmd", { group = group, pattern = "*.age", callback = read })
vim.api.nvim_create_autocmd("BufWriteCmd", { group = group, pattern = "*.age", callback = write })
