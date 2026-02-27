-- Ganti URL ini dengan link raw GitHub yang valid dan berisi script LENGKAP
local scriptUrl = "https://raw.githubusercontent.com/raihansanjaya123-a11y/Raihjn-Script/refs/heads/main/Pabrik%20Raihjn.lua"

-- Fungsi untuk mengambil dan menjalankan script
local success, result = pcall(function()
    local content = game:HttpGet(scriptUrl)
    loadstring(content)()
end)

-- Penanganan error
if not success then
    warn("Gagal memuat atau menjalankan script:")
    warn(result)
else
    print("Script Pabrik berhasil dimuat!")
end