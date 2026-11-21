#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <cstdio>
#include <filesystem>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <openssl/evp.h>

namespace fs = std::filesystem;

std::string sha1(const std::string &path)
{
    int fd = open(path.c_str(), O_RDONLY);
    if (fd < 0)
        return "";

    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_sha1(), NULL);

    char buf[4096];
    ssize_t n;
    while ((n = read(fd, buf, sizeof(buf))) > 0)
        EVP_DigestUpdate(ctx, buf, n);
    close(fd);

    unsigned char hash[EVP_MAX_MD_SIZE];
    unsigned int len;
    EVP_DigestFinal_ex(ctx, hash, &len);
    EVP_MD_CTX_free(ctx);

    if (n < 0)
        return "";

    std::string result;
    char hex[3];
    for (unsigned int i = 0; i < len; i++) {
        snprintf(hex, sizeof(hex), "%02x", hash[i]);
        result += hex;
    }
    return result;
}

int main(int argc, char *argv[])
{
    if (argc != 2) {
        std::cerr << "Использование: " << argv[0] << " <каталог>" << std::endl;
        return 1;
    }

    std::string dir = argv[1];
    if (!fs::is_directory(dir)) {
        std::cerr << dir << " - не каталог" << std::endl;
        return 1;
    }

    std::vector<std::string> files;
    for (const auto &entry : fs::recursive_directory_iterator(dir)) {
        if (entry.is_symlink() || !entry.is_regular_file())
            continue;
        files.push_back(entry.path().string());
    }
    std::cout << "Найдено файлов: " << files.size() << std::endl;

    std::map<std::string, std::string> first;
    int count = 0;

    for (const auto &file : files) {
        std::string h = sha1(file);
        if (h == "") {
            std::cerr << "Не удалось прочитать " << file << std::endl;
            continue;
        }

        if (first.count(h) == 0) {
            first[h] = file;
            continue;
        }

        std::string orig = first[h];
        struct stat a, b;
        stat(orig.c_str(), &a);
        stat(file.c_str(), &b);

        if (a.st_ino == b.st_ino && a.st_dev == b.st_dev)
            continue;
        if (a.st_dev != b.st_dev) {
            std::cerr << file << ": другая файловая система, пропускаем" << std::endl;
            continue;
        }

        if (unlink(file.c_str()) != 0) {
            perror(file.c_str());
            continue;
        }
        if (link(orig.c_str(), file.c_str()) != 0) {
            perror(file.c_str());
            continue;
        }
        std::cout << file << " -> " << orig << std::endl;
        count++;
    }

    std::cout << "Заменено на жёсткие ссылки: " << count << std::endl;
    return 0;
}
