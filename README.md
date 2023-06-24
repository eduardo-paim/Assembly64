Uma alternativa nova e aprimorada para os arquivos x86 block_api.asm e x64 block_api.asm. Ao modificar o método de hash dos nomes das APIs do Windows, é possível reduzir em 1 byte o tamanho de cada shellcode do Windows x86 e em 4 bytes todos os shellcodes do Windows x64. Como a maioria dos produtos de segurança procura por hashes ROR13 conhecidos dos nomes das funções da API do Windows, a mudança no método de hash diminuirá a taxa de detecção dos shellcodes do Metasploit para Windows. Além disso, o novo método proposto possui uma taxa de colisão significativamente menor em comparação ao ROR13.



Novo Método de Hashing
Aproveitei a instrução CRC32 para calcular o valor CRC32 do Windows, que é o mesmo método utilizado no antigo block_api.asm. Ao substituir os hashes ROR13 pelos valores CRC32 no arquivo crc32_api.asm, é possível encontrar o endereço da função desejada da mesma maneira que era feito no antigo block_api.asm. Não são necessários registros adicionais. Realizei testes com o arquivo crc32_api.asm para todos os shellcodes existentes do Windows no Metasploit, e funcionou sem erros. O arquivo crc32_hash.py pode ser utilizado para calcular o valor CRC32 de uma entrada fornecida, assim como o arquivo hash.py.


No entanto, há um porém. A instrução CRC32 é relativamente nova e foi adicionada com o SSE4, o que pode causar problemas em CPUs mais antigas. Embora pareça funcionar corretamente em modelos fabricados após 2006, não é possível prever o que ocorrerá ao executar uma instrução não suportada em uma CPU antiga. Infelizmente, não foi possível encontrar hardware antigo o suficiente para realizar testes.# Assembly64
