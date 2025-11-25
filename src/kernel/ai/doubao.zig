pub fn gen(prompt: []const u8, lang: []const u8) []const u8 {
    if (lang.len >= 3 and lang[0] == 'z') {
        if (prompt.len >= 4 and prompt[0] == 's') return "pub fn seed() void {}";
        return "pub fn main() void {}";
    }
    return "int main(){return 0;}";
}
