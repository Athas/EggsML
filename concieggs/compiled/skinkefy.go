package main

import (
	"bufio"
	"fmt"
	"math/rand"
	"os"
	"path"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

const (
	// Percentage chance for a word to become a skinke.
	skinkeFactor = 25
	// Minimum length of a word allowed to be skinke.
	skinkeLength = 4
	scRegular    = iota + 1
	scCapitalised
	scFullUpper
)

type skinkeList []string

var Skinker skinkeList
var IkkeSkinker skinkeList
var UseWordList bool
var Nouns []string

func loadWords(words *[]string, filename string) {
	wordsFile, err := os.Open(path.Join(os.Getenv("CONCIEGGS_DB_DIR"), filename))
	if err != nil {
		return
	}
	defer wordsFile.Close()
	r := bufio.NewReader(wordsFile)
	for {
		if line, err := r.ReadString('\n'); err != nil {
			break
		} else {
			line = strings.Trim(line, " \t\n")
			*words = append(*words, line)
		}
	}
}

func main() {
	loadWords(&Nouns, "ordbog-dansk-navneord")
	UseWordList = len(Nouns)+len(Verbs) > 0
	rand.Seed(time.Now().Unix())
	// Using bufio.Reader, because we cannot bufio.Scanner,
	// because the machine uses go 1.0.2.
	// And Debian is a classy gentleman system.
	read := bufio.NewReader(os.Stdin)
	str, _ := read.ReadString('\n')
	// Match all words! \p{L} is all unicode letters.
	r, _ := regexp.Compile("([\\p{L}]+)")
	out := strings.Trim(r.ReplaceAllStringFunc(str, skinkefy), "\n ")
	fmt.Println(out)
}

func oneSkinke(condition int, word string) string {
	switch condition {
	case scFullUpper:
		word = strings.ToUpper(word)
	case scCapitalised:
		// Get first rune
		r, s := utf8.DecodeRuneInString(word)
		rs := strconv.QuoteRune(unicode.ToUpper(r))
		// And put it together with the word.
		word = rs[1:len(rs)-1] + word[s:]
	}
	return word
}

func oneSkinkeNoun(condition int, plural bool, definitive bool) string {
	var word string
	switch {
	// Maybe also in verb form?  e.g. 'skinkede'
	case plural:
		word = "skinker"
	case definitive:
		word = "skinken"
	default:
		word = "skinke"
	}
	return oneSkinke(condition, word)
}

func foundWord(words []string, word string) bool {
	found := false
	for _, w := range words {
		if w == strings.ToLower(word) {
			found = true
			break
		}
	}
	return found
}

func skinkefy(word string) string {
	isNoun := foundWord(Nouns, word)
	if UseWordList && !isNoun { 
		return word
	}
	camelCaseCheckR, _ := regexp.Compile("[\\p{Ll}][\\p{Lu}][\\p{L}]+")
	camelCaseR, _ := regexp.Compile("([\\p{Lu}][\\p{Ll}]+|[\\p{Lu}]+)")
	if camelCaseCheckR.MatchString(word) {
		word = camelCaseR.ReplaceAllStringFunc(word, skinkefy)
	} else {
		if (rand.Intn(100) <= skinkeFactor &&
			!IkkeSkinker.Contains(word) &&
			isNoun &&
			len(word) >= skinkeLength) ||
			Skinker.Contains(word) {
			// Yes, we got a skinke, let's add the word.
			Skinker.Append(word)
			var skinkeCondition int
			first, _ := utf8.DecodeRuneInString(word)
			switch {
			case strings.ToUpper(word) == word:
				skinkeCondition = scFullUpper
			case unicode.ToUpper(first) == first:
				skinkeCondition = scCapitalised
			default:
				skinkeCondition = scRegular
			}
			// Get the last two letters of the word.
			end, size := utf8.DecodeLastRuneInString(word)
			end2, _ := utf8.DecodeLastRuneInString(word[:len(word)-size])
			end = unicode.ToUpper(end)
			end2 = unicode.ToUpper(end2)
			// If it ends on R, it's plural.  That's our rule!
			// If it ends on ET/EN, it's definitive.
			if isNoun {
				word = oneSkinkeNoun(skinkeCondition, end == 'R', end2 == 'E' && (end == 'T' || end == 'N'))
			}
		} else {
			// Not a skinke word.  If it appears again, it should remain
			// not skinke.
			IkkeSkinker.Append(word)
		}
	}
	return word
}

func (sl *skinkeList) Contains(str string) bool {
	str = strings.ToUpper(str)
	for _, s := range *sl {
		if s == str {
			return true
		}
	}
	return false
}

func (sl *skinkeList) Append(str string) {
	str = strings.ToUpper(str)
	*sl = append(*sl, str)
}

