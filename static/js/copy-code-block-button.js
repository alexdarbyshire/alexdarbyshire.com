/**
 * Sources:
 * https://romankurnovskii.com/en/posts/hugo-add-copy-button-on-highlight-block/
 * https://www.dannyguo.com/blog/how-to-add-copy-to-clipboard-buttons-to-code-blocks-in-hugo/
 */

function addCopyButtonToCodeBlocks() {
    // Get all code blocks with a class of "language-*"
    const codeBlocks = document.querySelectorAll('code[class^="language-"]');

    // For each code block, add a copy button inside the block
    codeBlocks.forEach(codeBlock => {
        // Create the copy button element
        const copyButton = document.createElement('button');
        copyButton.classList.add('copy-code-button');
        copyButton.innerHTML = '<i class="far fa-copy"></i>';

        // Add a click event listener to the copy button
        copyButton.addEventListener('click', () => {
            // Copy the code inside the code block to the clipboard
            const codeToCopy = codeBlock.innerText;
            navigator.clipboard.writeText(codeToCopy);

            // Update the copy button text to indicate that the code has been copied
            copyButton.innerHTML = '<i class="fas fa-check"></i>';
            setTimeout(() => {
                copyButton.innerHTML = '<i class="far fa-copy"></i>';
            }, 1500);
        });

        // Add the copy button to the code block
        codeBlock.parentNode.insertBefore(copyButton, codeBlock);
    });
}



if (navigator && navigator.clipboard) {
    addCopyButtonToCodeBlocks(navigator.clipboard);
} else {
    var script = document.createElement('script');
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/clipboard-polyfill/2.7.0/clipboard-polyfill.promise.js';
    script.integrity = 'sha256-waClS2re9NUbXRsryKoof+F9qc1gjjIhc2eT7ZbIv94=';
    script.crossOrigin = 'anonymous';
    script.onload = function() {
        addCopyButtonToCodeBlocks(clipboard);
    };

    document.body.appendChild(script);
}